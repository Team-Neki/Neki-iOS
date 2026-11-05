//
//  ServerLogPipeline.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import os

/// 저장한 로그를 모아 서버로 보냅니다(Amplitude-Swift `EventPipeline`).
/// - Note: SDK처럼 쌓인 수·타이머·백그라운드 진입에 맞춰 보내고, 업로드는 한 번에 하나만 합니다. Android(`ServerAnalyticsLogger`)처럼 로그인 때도 보냅니다.
/// - Note: SDK처럼 네트워크 경로가 끊기거나, 연결 오류가 나거나, 7번 연속 실패하면 저장만 하고, 경로 감시가 연결됨을 알리면 한 번 보냅니다. SDK와 달리 실패 횟수는 보내서 성공했을 때만 0으로 되돌립니다.
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
        /// 실패한 뒤 다시 보내는 최대 횟수. 이만큼 다시 보내도 실패하면(7번째 연속 실패) 네트워크 경로가 바뀔 때까지 멈춥니다(SDK `flushMaxRetries`).
        var maximumRetryCount = 6
    }

    fileprivate enum SendOutcome {
        case delivered
        case stalled
        /// 연결 오류로 보내지 못함
        case disconnected
    }

    private let storage: ServerLogStorage
    private let client: ServerLogHttpClient
    private let tokenReader: any ServerLogAccessTokenReading
    private let backgroundTask: any ServerLogBackgroundTaskStarting
    private let networkPath: any NetworkPathObserving
    private let configuration: Configuration
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Int64
    private let jitter: @Sendable (Duration) -> Duration

    private var currentUserID: String?
    private var storedCountSinceUpload = 0
    private var failureCount = 0
    private var retryAvailableAt: Int64?
    /// 네트워크 경로로 나갈 수 있는지. 경로를 알기 전에는 나갈 수 있다고 봅니다.
    private var isPathSatisfied = true
    /// 연결 오류나 연속 실패로 멈췄는지. 경로 감시가 연결됨을 알리면 풉니다.
    private var isPausedAfterFailures = false
    private var uploadTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var networkTask: Task<Void, Never>?

    init(
        storage: ServerLogStorage = ServerLogStorage(),
        client: ServerLogHttpClient = ServerLogHttpClient(),
        tokenReader: any ServerLogAccessTokenReading,
        backgroundTask: any ServerLogBackgroundTaskStarting,
        networkPath: any NetworkPathObserving,
        configuration: Configuration = Configuration(),
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping @Sendable () -> Int64 = { Date().epochMilliseconds },
        jitter: @escaping @Sendable (Duration) -> Duration = { $0 * Double.random(in: 0...0.1) }
    ) {
        self.storage = storage
        self.client = client
        self.tokenReader = tokenReader
        self.backgroundTask = backgroundTask
        self.networkPath = networkPath
        self.configuration = configuration
        self.clock = clock
        self.now = now
        self.jitter = jitter
    }

    /// 타이머와 네트워크 경로 감시를 켭니다. SDK·Android와 같이 실행 직후에는 보내지 않고, 첫 전송은 타이머나 쌓인 수를 따릅니다.
    func start() {
        guard timerTask == nil else { return }
        timerTask = Task { [clock, flushInterval = configuration.flushInterval] in
            while Task.isCancelled == false {
                try? await clock.sleep(for: flushInterval)
                guard Task.isCancelled == false else { return }
                self.flush(ignoringRetryDelay: false)
            }
        }
        let pathUpdates = networkPath.updates()
        networkTask = Task {
            for await isSatisfied in pathUpdates {
                self.networkPathChanged(isSatisfied: isSatisfied)
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        retryTask?.cancel()
        uploadTask?.cancel()
        networkTask?.cancel()
        timerTask = nil
        retryTask = nil
        uploadTask = nil
        networkTask = nil
    }

    /// 토큰을 붙일 회원. 이 회원이 남긴 로그에만 토큰을 붙입니다.
    func updateCurrentUserID(_ userID: String?) {
        currentUserID = userID
    }

    /// 네트워크 경로가 바뀔 때(SDK `NetworkConnectivityCheckerPlugin`). 끊기면 멈추고, 연결됨이면 멈춤을 모두 풀고 멈춰 있었을 때만 한 번 보냅니다. 실패 횟수는 그대로 둡니다.
    func networkPathChanged(isSatisfied: Bool) {
        guard isSatisfied else {
            if isPathSatisfied { Logger.analytics.debug("네트워크 경로가 끊겨 서버 로그 전송을 멈춤") }
            isPathSatisfied = false
            cancelRetry()
            return
        }
        let wasOffline = isOffline
        isPathSatisfied = true
        isPausedAfterFailures = false
        guard wasOffline else { return }
        Logger.analytics.debug("네트워크 경로가 이어져 서버 로그를 다시 보냄")
        flush()
    }

    /// 로그를 저장하고, 쌓인 수가 기준에 닿으면 보냅니다.
    func put(_ event: ServerLogStoredEvent) async throws {
        try await storage.write(event)
        storedCountSinceUpload += 1
        if storedCountSinceUpload >= configuration.flushEventCount {
            flush(ignoringRetryDelay: false)
        }
    }

    /// 오프라인이 아니고 업로드 중이 아니면 바로 보냅니다.
    /// - Parameter ignoringRetryDelay: 백그라운드 진입처럼 지금 보내야 할 때는 실패 뒤 대기 시간을 무시합니다. 오프라인이면 이때도 보내지 않습니다.
    func flush(ignoringRetryDelay: Bool = true) {
        guard isOffline == false, uploadTask == nil else { return }
        if ignoringRetryDelay == false, let retryAvailableAt, now() < retryAvailableAt { return }
        uploadTask = Task { await self.uploadStoredEvents() }
    }

    /// 바로 보내고, 업로드가 끝나거나 `timeout`이 지날 때까지 기다립니다. 시간이 지나도 업로드는 이어서 합니다.
    /// 오프라인이면 새로 보내지 않으므로, 진행 중인 업로드가 없으면 바로 돌아옵니다.
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
        logRemoval(await storage.prune(now: now()))
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
            handleFailure(isConnectionFailure: outcome == .disconnected)
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
            let firstOutcome = await send(Array(batch[..<half]))
            guard firstOutcome == .delivered else { return firstOutcome }
            return await send(Array(batch[half...]))
        case .retryWithoutAuthorization, .retryLater:
            return .stalled
        case .retryUnexpected:
            Logger.analytics.error("계약에 없는 응답이라 로그를 남겨 둠: \(batch.count)건 \(String(describing: result), privacy: .public)")
            return .stalled
        case .waitForConnection:
            return .disconnected
        }
    }

    /// 지금 로그인한 회원이 남긴 로그에만 토큰을 붙입니다. 로그아웃·탈퇴 뒤 남은 로그는 토큰 없이 보냅니다.
    func accessToken(for batch: [ServerLogStoredEvent]) async -> String? {
        guard let userID = batch.first?.userIDAtOccurrence, userID == currentUserID else { return nil }
        return await tokenReader.usableAccessToken()
    }

    /// 오프라인이면 저장만 하고 보내지 않습니다.
    var isOffline: Bool {
        isPathSatisfied == false || isPausedAfterFailures
    }

    /// 보내지 못했을 때. SDK처럼 연결 오류는 첫 실패에, 그 밖은 `maximumRetryCount`번 다시 보내도 실패하면 멈춥니다. 오프라인이 아니면 대기 시간 뒤 다시 보냅니다.
    func handleFailure(isConnectionFailure: Bool) {
        // SDK와 달리 실패 횟수는 보내서 성공했을 때만 0으로 되돌립니다. 그래서 멈춘 뒤 다시 보낸 한 번이 실패하면 바로 다시 멈춥니다.
        failureCount += 1
        if isConnectionFailure || failureCount > configuration.maximumRetryCount {
            isPausedAfterFailures = true
            let reason = isConnectionFailure ? "연결 오류" : "\(failureCount)번 연속 실패"
            Logger.analytics.error("서버 로그 전송을 멈춤: \(reason, privacy: .public), 네트워크 경로가 바뀌면 다시 보냄")
        }
        if isOffline {
            cancelRetry()
        } else {
            scheduleRetry()
        }
    }

    func scheduleRetry() {
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

    /// 기다리던 재시도와 대기 시각을 지웁니다.
    func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
        retryAvailableAt = nil
    }

    /// 보관 한도로 지운 로그와 읽지 못해 격리한 파일이 있으면, 정책상 삭제와 손상을 나눠 진단을 남깁니다.
    func logRemoval(_ result: ServerLogStorage.PruneResult) {
        if result.expired + result.overCount + result.overSize > 0 {
            Logger.analytics.error("보관 한도로 로그를 지움: 기간 \(result.expired)건, 개수 \(result.overCount)건, 용량 \(result.overSize)건")
        }
        if result.quarantined > 0 {
            Logger.analytics.error("읽지 못한 로그 파일을 격리함: \(result.quarantined)건")
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
    var now: @Sendable () -> Date = Date.init

    func usableAccessToken() async -> String? {
        guard let tokens = try? await reader.fetchStoredTokens(),
              tokens.isRefreshNeeded(at: now()) == false
        else { return nil }
        return tokens.accessToken
    }
}
