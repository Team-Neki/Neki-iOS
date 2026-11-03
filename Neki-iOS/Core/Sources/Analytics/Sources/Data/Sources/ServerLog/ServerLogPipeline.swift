//
//  ServerLogPipeline.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import os

/// 저장한 로그를 모아 서버로 보냅니다(Amplitude-Swift `EventPipeline`).
/// - Note: SDK처럼 쌓인 수·타이머·백그라운드 진입에 맞춰 보내고, 업로드는 한 번에 하나만 합니다. Android(`ServerAnalyticsLogger`)처럼 로그인 때도 보냅니다. SDK와 달리 실패가 이어져도 멈추지 않고 보관 한도 안에서 계속 다시 보냅니다.
actor ServerLogPipeline {
    struct Configuration: Sendable {
        /// 이만큼 쌓이면 바로 보냅니다.
        var flushEventCount = 100
        /// 이 간격마다 보냅니다.
        var flushInterval: Duration = .seconds(30)
        /// 실패한 뒤 다시 보내기까지의 최소 대기 시간. 실패할 때마다 두 배로 늘립니다.
        var minimumRetryDelay: Duration = .seconds(1)
        /// 실패한 뒤 다시 보내기까지의 최대 대기 시간
        var maximumRetryDelay: Duration = .seconds(300)
    }

    fileprivate enum SendOutcome {
        case delivered
        case stalled
    }

    private let storage: ServerLogStorage
    private let client: ServerLogHttpClient
    private let tokenReader: any ServerLogAccessTokenReading
    private let backgroundTask: any ServerLogBackgroundTaskStarting
    private let configuration: Configuration
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Int64
    private let jitter: @Sendable (Duration) -> Duration

    private var currentUserID: String?
    private var storedCountSinceUpload = 0
    private var failureCount = 0
    private var retryAvailableAt: Int64?
    private var uploadTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    init(
        storage: ServerLogStorage = ServerLogStorage(),
        client: ServerLogHttpClient = ServerLogHttpClient(),
        tokenReader: any ServerLogAccessTokenReading,
        backgroundTask: any ServerLogBackgroundTaskStarting,
        configuration: Configuration = Configuration(),
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping @Sendable () -> Int64 = { Date().epochMilliseconds },
        jitter: @escaping @Sendable (Duration) -> Duration = { $0 * Double.random(in: 0...0.1) }
    ) {
        self.storage = storage
        self.client = client
        self.tokenReader = tokenReader
        self.backgroundTask = backgroundTask
        self.configuration = configuration
        self.clock = clock
        self.now = now
        self.jitter = jitter
    }

    /// 타이머를 켭니다. SDK·Android와 같이 실행 직후에는 보내지 않고, 첫 전송은 타이머나 쌓인 수를 따릅니다.
    func start() {
        guard timerTask == nil else { return }
        timerTask = Task { [clock, flushInterval = configuration.flushInterval] in
            while Task.isCancelled == false {
                try? await clock.sleep(for: flushInterval)
                guard Task.isCancelled == false else { return }
                self.flush(ignoringRetryDelay: false)
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        retryTask?.cancel()
        uploadTask?.cancel()
        timerTask = nil
        retryTask = nil
        uploadTask = nil
    }

    /// 토큰을 붙일 회원. 이 회원이 남긴 로그에만 토큰을 붙입니다.
    func updateCurrentUserID(_ userID: String?) {
        currentUserID = userID
    }

    /// 로그를 저장하고, 쌓인 수가 기준에 닿으면 보냅니다.
    func put(_ event: ServerLogStoredEvent) async throws {
        try await storage.write(event)
        storedCountSinceUpload += 1
        if storedCountSinceUpload >= configuration.flushEventCount {
            flush(ignoringRetryDelay: false)
        }
    }

    /// 업로드 중이 아니면 바로 보냅니다.
    /// - Parameter ignoringRetryDelay: 백그라운드 진입처럼 지금 보내야 할 때는 실패 뒤 대기 시간을 무시합니다.
    func flush(ignoringRetryDelay: Bool = true) {
        guard uploadTask == nil else { return }
        if ignoringRetryDelay == false, let retryAvailableAt, now() < retryAvailableAt { return }
        uploadTask = Task { await self.uploadStoredEvents() }
    }

    /// 바로 보내고, 업로드가 끝나거나 `timeout`이 지날 때까지 기다립니다. 시간이 지나도 업로드는 이어서 합니다.
    func flushAndWait(timeout: Duration) async {
        flush()
        guard let uploadTask else { return }
        await withCheckedContinuation { [clock] (continuation: CheckedContinuation<Void, Never>) in
            let resumption = OnceResumption(continuation)
            let timeoutTask = Task {
                try? await clock.sleep(for: timeout)
                resumption.resume()
            }
            Task {
                await uploadTask.value
                timeoutTask.cancel()
                resumption.resume()
            }
        }
    }

    /// 진행 중인 업로드가 끝날 때까지 기다립니다.
    func waitForUpload() async {
        await uploadTask?.value
    }

    /// 회원이 남긴 로그를 보내지 않고 지웁니다(회원 탈퇴).
    func removeEvents(userID: String) async {
        let events = await storage.events().filter { $0.userIDAtOccurrence == userID }
        await storage.remove(events)
    }

    /// 실패 횟수에 따른 대기 시간: 최소 대기 시간에서 두 배씩 늘려 최대 대기 시간까지
    static func retryDelay(failureCount: Int, configuration: Configuration) -> Duration {
        let exponent = min(max(failureCount - 1, 0), 20)
        return min(configuration.minimumRetryDelay * (1 << exponent), configuration.maximumRetryDelay)
    }

    /// 맨 앞 로그와 같은 회원이 남긴 로그를 이어서, 요청 하나에 담을 수 있는 만큼 묶습니다.
    static func nextBatch(from events: [ServerLogStoredEvent]) -> [ServerLogStoredEvent]? {
        guard let first = events.first else { return nil }
        let sameUserEvents = events.prefix { $0.userIDAtOccurrence == first.userIDAtOccurrence }
        let count = ServerLogRequest.fittingCount(logSizes: sameUserEvents.map(\.log.count))
        return Array(sameUserEvents.prefix(max(count, 1)))
    }
}


// MARK: - Upload

private extension ServerLogPipeline {
    func uploadStoredEvents() async {
        let finishBackgroundTask = await backgroundTask.begin()
        await storage.prune(now: now())
        var outcome = SendOutcome.delivered
        var deliveredCount = 0
        // 목록은 비었을 때만 다시 읽고, 보낸 배치만큼 앞에서 잘라 냅니다.
        var pending: [ServerLogStoredEvent] = []
        while Task.isCancelled == false {
            if pending.isEmpty { pending = await storage.events() }
            guard let candidate = Self.nextBatch(from: pending) else { break }
            // 업로드를 기다리는 동안 탈퇴로 지운 로그는 보내지 않도록, 배치가 남아 있는지 확인하고 빠졌으면 다시 읽습니다.
            let batch = await storage.existing(candidate)
            guard batch.count == candidate.count else {
                pending = []
                continue
            }
            outcome = await send(batch)
            guard outcome == .delivered else { break }
            deliveredCount += batch.count
            pending.removeFirst(batch.count)
        }
        if outcome == .delivered {
            failureCount = 0
            retryAvailableAt = nil
            storedCountSinceUpload = 0
        } else {
            scheduleRetry()
        }
        await logStatus(deliveredCount: deliveredCount)
        uploadTask = nil
        await finishBackgroundTask()
    }

    func send(_ batch: [ServerLogStoredEvent]) async -> SendOutcome {
        let body = ServerLogRequest.body(logs: batch.map(\.log))
        let accessToken = await accessToken(for: batch)
        var result = await client.upload(body: body, accessToken: accessToken)
        var action = ServerLogResponseHandler.action(for: result, logCount: batch.count, sentWithAuthorization: accessToken != nil)
        if action == .retryWithoutAuthorization {
            // 탈퇴로 지운 로그는 토큰 없이 다시 보내지 않습니다.
            guard await storage.existing(batch).count == batch.count else { return .delivered }
            result = await client.upload(body: body, accessToken: nil)
            action = ServerLogResponseHandler.action(for: result, logCount: batch.count, sentWithAuthorization: false)
        }

        switch action {
        case .remove:
            await storage.remove(batch)
            return .delivered
        case .drop:
            Logger.analytics.error("서버가 받지 않는 로그를 버림: \(batch[0].eventID, privacy: .public) \(String(describing: result), privacy: .public)")
            await storage.remove(batch)
            return .delivered
        case .split:
            let half = batch.count / 2
            guard await send(Array(batch[..<half])) == .delivered else { return .stalled }
            return await send(Array(batch[half...]))
        case .retryWithoutAuthorization, .retryLater, .waitForConnection:
            return .stalled
        }
    }

    /// 지금 로그인한 회원이 남긴 로그에만 토큰을 붙입니다. 로그아웃·탈퇴 뒤 남은 로그는 토큰 없이 보냅니다.
    func accessToken(for batch: [ServerLogStoredEvent]) async -> String? {
        guard let userID = batch.first?.userIDAtOccurrence, userID == currentUserID else { return nil }
        return await tokenReader.usableAccessToken()
    }

    func scheduleRetry() {
        failureCount += 1
        let baseDelay = Self.retryDelay(failureCount: failureCount, configuration: configuration)
        let delay = baseDelay + jitter(baseDelay)
        retryAvailableAt = now() + delay.milliseconds
        retryTask?.cancel()
        retryTask = Task { [clock] in
            try? await clock.sleep(for: delay)
            guard Task.isCancelled == false else { return }
            self.flush()
        }
    }

    func logStatus(deliveredCount: Int) async {
        let status = await storage.status()
        let oldestAge = status.oldestOccurredAtMilliseconds.map { (now() - $0) / 1_000 } ?? 0
        Logger.analytics.debug("서버 로그 전송: 보냄 \(deliveredCount)건, 남음 \(status.count)건, 가장 오래된 로그 \(oldestAge)초 전, 연속 실패 \(self.failureCount)회")
    }
}

/// 먼저 끝난 쪽만 기다림을 끝내도록 한 번만 이어 갑니다.
private final class OnceResumption: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume()
    }
}

private extension Duration {
    var milliseconds: Int64 {
        components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
    }
}


// MARK: - Access Token

/// 서버 로그에 붙일 액세스 토큰을 읽습니다. 재발급과 인증 실패 보고는 하지 않습니다.
protocol ServerLogAccessTokenReading: Sendable {
    /// 저장된 토큰이 없거나 만료 5분 전부터는 `nil`을 돌려줘, 토큰 없이 보내게 합니다.
    func usableAccessToken() async -> String?
}

struct ServerLogStoredTokenReader: ServerLogAccessTokenReading {
    let reader: any StoredAuthTokenReading

    func usableAccessToken() async -> String? {
        guard let tokens = try? await reader.fetchStoredTokens(), tokens.refreshNeeded == false else { return nil }
        return tokens.accessToken
    }
}
