//
//  ServerAnalyticsRepository.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import os
import UIKit

/// 행동 이벤트를 서버(`POST /api/logs`)로 보내는 저장소
/// - Note: Amplitude-Swift의 흐름(`track` → 세션 → 문맥 → 저장 → 전송)을 옮겼습니다. 이벤트는 디스크에 쓰고 바로 반환하며, 전송 실패는 이 안에서 끝나 Amplitude 기록과 기능 결과에 영향을 주지 않습니다.
/// - Note: SDK가 자동으로 보내는 이벤트(`session_start`·`session_end`, `[Amplitude] Application …`)는 서버로 보내지 않습니다. Amplitude SDK 제거 시 이 이벤트를 자체로 만들지 정합니다.
final actor ServerAnalyticsRepository: AnalyticsRepository {
    private let identity: any AnalyticsIdentityProviding
    private let pipeline: ServerLogPipeline
    private let sessionStore: ServerLogSessionStore
    private let observesLifecycle: Bool
    private let now: @Sendable () -> Int64
    private let isApplicationActive: @Sendable () async -> Bool
    private let makeContext: @Sendable () async -> ServerLogContext

    private var session: ServerLogSession
    private var context: ServerLogContext?
    private var isForeground = false
    private var isStarted = false
    private var lifecycleObserver: ServerLogLifecycleObserver?

    init(
        identity: any AnalyticsIdentityProviding,
        pipeline: ServerLogPipeline,
        sessionStore: ServerLogSessionStore = ServerLogSessionStore(),
        observesLifecycle: Bool = true,
        now: @escaping @Sendable () -> Int64 = { Date().epochMilliseconds },
        isApplicationActive: @escaping @Sendable () async -> Bool = {
            await MainActor.run { UIApplication.shared.applicationState == .active }
        },
        makeContext: @escaping @Sendable () async -> ServerLogContext = {
            await MainActor.run { ServerLogContext.current() }
        }
    ) {
        self.identity = identity
        self.pipeline = pipeline
        self.sessionStore = sessionStore
        self.observesLifecycle = observesLifecycle
        self.now = now
        self.isApplicationActive = isApplicationActive
        self.makeContext = makeContext
        self.session = sessionStore.load()
    }

    func initialize() async throws {
        await startIfNeeded()
    }

    func setUserSession(with userID: Int?, changedAt: Date) async {
        await updateUserID(userID.map(String.init), at: changedAt.epochMilliseconds)
        // Android와 같이 로그인(자동 로그인 포함)하면 쌓인 로그를 보냅니다.
        if userID != nil {
            await pipeline.flush(ignoringRetryDelay: false)
        }
    }

    func endUserSession(with event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        if event.name == .withdraw, let userID = session.userID {
            // 탈퇴한 회원의 남은 로그는 보내지 않습니다. 탈퇴 이벤트는 토큰이 지워진 뒤라 토큰 없이 갑니다.
            await pipeline.removeEvents(userID: userID)
        }
        await record(event, occurrence: occurrence)
        await updateUserID(nil, at: occurrence.occurredAtMilliseconds)
    }

    func logEvent(_ event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        await record(event, occurrence: occurrence)
    }

    /// 지금 보내고 최대 3초까지 기다립니다. 회원 탈퇴 요청 전에 남은 로그를 보내 두려고 씁니다.
    func flush() async {
        guard isStarted else { return }
        await pipeline.flushAndWait(timeout: .seconds(3))
    }
}


// MARK: - Lifecycle

extension ServerAnalyticsRepository {
    /// 포그라운드로 돌아올 때(SDK `onEnterForeground`). SDK·Android와 같이 이때는 보내지 않습니다.
    func applicationWillEnterForeground() async {
        session.enterForeground(at: now())
        sessionStore.save(session)
        isForeground = true
    }

    /// SDK처럼 실행 직후처럼 아직 포그라운드가 아닐 때만 받습니다. 제어 센터 등에서 돌아오는 활성화는 무시합니다.
    func applicationDidBecomeActive() async {
        guard isForeground == false else { return }
        await applicationWillEnterForeground()
    }

    /// 백그라운드로 갈 때(SDK `onExitForeground`)
    func applicationDidEnterBackground() async {
        session.exitForeground(at: now())
        sessionStore.save(session)
        isForeground = false
        await pipeline.flush()
    }
}


// MARK: - Session Comparison

extension ServerAnalyticsRepository {
    /// SDK와 서버 로그는 포그라운드 진입을 따로 받아, 같은 세션도 시작 시각(세션 ID)이 조금 다를 수 있습니다. 1분 넘게 차이 날 때만 다른 세션으로 봅니다.
    static func isSameSession(_ sdkSessionID: Int64, _ computedSessionID: Int64) -> Bool {
        abs(sdkSessionID - computedSessionID) < 60_000
    }
}


// MARK: - Recording

private extension ServerAnalyticsRepository {
    /// Amplitude가 켜진 빌드에서 처음 쓸 때 한 번 생명주기 관찰과 전송을 시작합니다.
    func startIfNeeded() async {
        guard isStarted == false else { return }
        isStarted = true
        guard await identity.deviceID() != nil else {
            isStarted = false
            return
        }
        await pipeline.updateCurrentUserID(session.userID)
        if observesLifecycle {
            lifecycleObserver = ServerLogLifecycleObserver(
                onEnterForeground: { [weak self] in await self?.applicationWillEnterForeground() },
                onBecomeActive: { [weak self] in await self?.applicationDidBecomeActive() },
                onEnterBackground: { [weak self] in await self?.applicationDidEnterBackground() }
            )
        }
        if await isApplicationActive() {
            await applicationWillEnterForeground()
        }
        await pipeline.start()
    }

    func record(_ event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        // Amplitude가 꺼진 빌드(키 누락)에서는 기기 ID가 없으므로 서버로도 보내지 않습니다.
        // Amplitude SDK 제거 시 이 조건을 지웁니다. 기기 ID와 세션 ID를 자체로 만들 수 있기 때문입니다.
        guard let deviceID = await identity.deviceID() else { return }
        await startIfNeeded()
        let sdkSessionID = await identity.sessionID()
        let numbering = session.number(
            eventAt: occurrence.occurredAtMilliseconds,
            inForeground: isForeground,
            sessionID: sdkSessionID
        )
        sessionStore.save(session)
        if Self.isSameSession(numbering.sessionID, numbering.computedSessionID) == false {
            Logger.analytics.debug("세션 ID가 SDK와 다름: SDK \(numbering.sessionID), 자체 계산 \(numbering.computedSessionID)")
        }

        let log = ServerLogEvent(
            event: event,
            occurrence: occurrence,
            sessionID: numbering.sessionID,
            sequenceNumber: numbering.sequenceNumber,
            deviceID: deviceID,
            userIDAtOccurrence: session.userID,
            context: await currentContext()
        )
        do {
            let data = try log.encodedLog()
            guard ServerLogRequest.isWithinLogLimit(data) else {
                Logger.analytics.error("1,000KiB를 넘는 로그를 버림: \(log.eventType, privacy: .public) \(data.count)B")
                return
            }
            try await pipeline.put(ServerLogStoredEvent(event: log, log: data))
        } catch {
            Logger.analytics.error("로그를 저장하지 못함: \(log.eventType, privacy: .public) \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 회원 ID를 바꿉니다. 회원 ID가 없어지거나 다른 회원으로 바뀌면 같은 시각으로 새 세션을 엽니다(Amplitude 저장소와 같은 규칙).
    func updateUserID(_ userID: String?, at timestamp: Int64) async {
        session.updateUserID(userID, at: timestamp)
        sessionStore.save(session)
        await pipeline.updateCurrentUserID(userID)
    }

    func currentContext() async -> ServerLogContext {
        if let context { return context }
        let context = await makeContext()
        self.context = context
        return context
    }
}


// MARK: - Identity

/// 서버 로그에 넣을 기기 ID와 세션 ID를 읽습니다. 지금은 Amplitude 저장소가 SDK 값을 넘깁니다.
protocol AnalyticsIdentityProviding: Sendable {
    /// Amplitude가 꺼져 있으면 `nil`
    func deviceID() async -> String?
    /// 세션이 없으면 -1
    func sessionID() async -> Int64
}


// MARK: - Lifecycle Observer

/// 앱이 포그라운드·백그라운드로 바뀌는 것을 알려 줍니다(Amplitude-Swift `IOSLifecycleMonitor`).
final class ServerLogLifecycleObserver: Sendable {
    private let tasks: [Task<Void, Never>]

    init(
        onEnterForeground: @escaping @Sendable () async -> Void,
        onBecomeActive: @escaping @Sendable () async -> Void,
        onEnterBackground: @escaping @Sendable () async -> Void
    ) {
        tasks = [
            Self.observe(UIApplication.willEnterForegroundNotification, perform: onEnterForeground),
            Self.observe(UIApplication.didBecomeActiveNotification, perform: onBecomeActive),
            Self.observe(UIApplication.didEnterBackgroundNotification, perform: onEnterBackground)
        ]
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    private static func observe(
        _ name: Notification.Name,
        perform action: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            for await _ in NotificationCenter.default.notifications(named: name) {
                await action()
            }
        }
    }
}
