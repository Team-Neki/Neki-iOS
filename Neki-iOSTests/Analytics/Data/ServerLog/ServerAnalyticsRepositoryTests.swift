//
//  ServerAnalyticsRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerAnalyticsRepositoryTests {
    @Test("이벤트에 SDK의 기기·세션 ID, 세션 안 순번, 발생 당시 회원 ID, 문맥을 담아 저장한다")
    func logEvent_storesLogWithIdentityAndSequence() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 5_000)
        try await withRepository(identity: identity) { repository, storage, _, _ in
            await repository.setUserSession(with: 1, changedAt: Date(timeIntervalSince1970: 4))
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 5_000))
            await repository.logEvent(AnalyticsEventStub.mapView, occurrence: occurrence(id: 2, at: 6_000))

            let logs = try await storedLogs(in: storage)

            #expect(logs.count == 2)
            #expect(logs[0]["eventType"] as? String == "app_open")
            #expect(logs[0]["sessionId"] as? Int64 == 5_000)
            #expect(logs[0]["sequenceNumber"] as? Int == 1)
            #expect(logs[0]["deviceId"] as? String == "device-1")
            #expect(logs[0]["userIdAtOccurrence"] as? String == "1")
            #expect(logs[0]["appVersion"] as? String == "1.2.9")
            #expect(logs[0]["context"] as? [String: String] == ["osName": "ios"])
            #expect(logs[1]["eventType"] as? String == "map_view")
            #expect(logs[1]["sequenceNumber"] as? Int == 2)
        }
    }

    @Test("순번은 발생 시각이 아니라 기록한 순서대로 매긴다")
    func logEvent_numbersInRecordOrder() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 5_000)
        try await withRepository(identity: identity) { repository, storage, _, _ in
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 6_000))
            await repository.logEvent(AnalyticsEventStub.mapView, occurrence: occurrence(id: 2, at: 5_500))

            let logs = try await storedLogs(in: storage)

            #expect(logs.map { $0["eventType"] as? String } == ["map_view", "app_open"])
            #expect(logs.map { $0["sequenceNumber"] as? Int } == [2, 1])
        }
    }

    @Test("Amplitude가 꺼진 빌드처럼 기기 ID가 없으면 서버로 보낼 로그를 남기지 않는다")
    func logEvent_withoutDeviceID_storesNothing() async throws {
        let identity = IdentityStub(deviceID: nil, sessionID: 5_000)
        try await withRepository(identity: identity) { repository, storage, _, _ in
            try await repository.initialize()
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 5_000))

            #expect(await storage.events().isEmpty)
        }
    }

    @Test("SDK 세션이 아직 없으면 SDK가 열 세션과 같은 자체 계산 값을 보낸다")
    func logEvent_beforeSDKSession_usesComputedSessionID() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: -1)
        try await withRepository(identity: identity) { repository, storage, _, _ in
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 7_000))

            let logs = try await storedLogs(in: storage)

            #expect(logs.first?["sessionId"] as? Int64 == 7_000)
            #expect(logs.first?["sequenceNumber"] as? Int == 1)
        }
    }

    @Test("로그아웃하면 그 시각으로 새 세션을 열고, 이후 로그는 회원 ID 없이 남긴다")
    func setUserSession_whenSignedOut_startsSessionAndClearsUser() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 2_000)
        try await withRepository(identity: identity) { repository, storage, sessionStore, _ in
            await repository.setUserSession(with: 1, changedAt: Date(timeIntervalSince1970: 1))
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 2_000))

            await repository.setUserSession(with: nil, changedAt: Date(timeIntervalSince1970: 9))
            await repository.logEvent(AnalyticsEventStub.mapView, occurrence: occurrence(id: 2, at: 9_500))
            let logs = try await storedLogs(in: storage)
            let session = sessionStore.load()

            #expect(session.sessionID == 9_000)
            #expect(session.userID == nil)
            #expect(logs.map { $0["userIdAtOccurrence"] as? String } == ["1", nil])
        }
    }

    @Test("탈퇴하면 그 회원의 남은 로그를 지우고 탈퇴 이벤트만 남긴다")
    func endUserSession_whenWithdrawn_removesUserLogs() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 2_000)
        try await withRepository(identity: identity) { repository, storage, sessionStore, _ in
            await repository.setUserSession(with: 1, changedAt: Date(timeIntervalSince1970: 1))
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 2_000))
            await repository.logEvent(AnalyticsEventStub.mapView, occurrence: occurrence(id: 2, at: 3_000))

            await repository.endUserSession(with: AnalyticsEventStub.withdraw, occurrence: occurrence(id: 3, at: 4_000))
            let logs = try await storedLogs(in: storage)

            #expect(logs.map { $0["eventType"] as? String } == ["mypage_withdraw"])
            #expect(logs.first?["userIdAtOccurrence"] as? String == "1")
            #expect(sessionStore.load().userID == nil)
            #expect(sessionStore.load().sessionID == 4_000)
        }
    }

    @Test("로그아웃 이벤트는 남은 로그를 지우지 않는다")
    func endUserSession_whenSignedOut_keepsUserLogs() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 2_000)
        try await withRepository(identity: identity) { repository, storage, _, _ in
            await repository.setUserSession(with: 1, changedAt: Date(timeIntervalSince1970: 1))
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 2_000))

            await repository.endUserSession(with: AnalyticsEventStub.logout, occurrence: occurrence(id: 2, at: 3_000))
            let logs = try await storedLogs(in: storage)

            #expect(logs.map { $0["eventType"] as? String } == ["app_open", "mypage_logout"])
        }
    }

    @Test("백그라운드에 들어간 시각부터 5분이 지나 돌아오면 새 세션을 연다")
    func lifecycle_returningAfterTimeout_startsSession() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 1_000)
        try await withRepository(identity: identity) { repository, _, sessionStore, now in
            now.value = 1_000
            await repository.applicationWillEnterForeground()
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 1_000))

            now.value = 3_600_000
            await repository.applicationDidEnterBackground()
            now.value = 3_600_000 + 360_000
            await repository.applicationWillEnterForeground()

            #expect(sessionStore.load().sessionID == 3_600_000 + 360_000)
        }
    }

    @Test("로그인하면 쌓인 로그를 보낸다")
    func setUserSession_whenSignedIn_sendsStoredLogs() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 1_000)
        try await withFixture(identity: identity) { fixture in
            await fixture.repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 1_000))
            await fixture.pipeline.waitForUpload()
            let requestCountBeforeSignIn = fixture.session.requests.count

            await fixture.repository.setUserSession(with: 1, changedAt: Date(timeIntervalSince1970: 2))
            await fixture.pipeline.waitForUpload()

            #expect(requestCountBeforeSignIn == 0)
            #expect(fixture.session.requests.map(\.logEventIDs) == [[occurrence(id: 1, at: 1_000).id]])
        }
    }

    @Test("포그라운드로 돌아올 때는 보내지 않고, 백그라운드에 들어갈 때 보낸다")
    func lifecycle_sendsOnlyWhenEnteringBackground() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 1_000)
        try await withFixture(identity: identity) { fixture in
            await fixture.repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 1_000))
            await fixture.repository.applicationWillEnterForeground()
            await fixture.pipeline.waitForUpload()
            let requestCountAfterForeground = fixture.session.requests.count

            await fixture.repository.applicationDidEnterBackground()
            await fixture.pipeline.waitForUpload()

            #expect(requestCountAfterForeground == 0)
            #expect(fixture.session.requests.count == 1)
        }
    }

    @Test(
        "포그라운드 진입을 따로 받아 생긴 1분 미만의 차이는 같은 세션으로 본다",
        arguments: zip([Int64(0), 835, -59_999, 60_000, -300_000], [true, true, true, false, false])
    )
    func isSameSession_allowsSmallStartGap(difference: Int64, expected: Bool) {
        #expect(ServerAnalyticsRepository.isSameSession(1_793_634_073_138, 1_793_634_073_138 + difference) == expected)
    }

    @Test("포그라운드에 있는 동안 다시 활성화되는 것은 세션을 바꾸지 않는다")
    func lifecycle_becomingActiveInForeground_keepsSession() async throws {
        let identity = IdentityStub(deviceID: "device-1", sessionID: 1_000)
        try await withRepository(identity: identity) { repository, _, sessionStore, now in
            now.value = 1_000
            await repository.applicationWillEnterForeground()
            await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence(id: 1, at: 1_000))

            now.value = 1_000 + 600_000
            await repository.applicationDidBecomeActive()

            #expect(sessionStore.load().sessionID == 1_000)
        }
    }
}


// MARK: - Helpers

private extension ServerAnalyticsRepositoryTests {
    actor IdentityStub: AnalyticsIdentityProviding {
        private let device: String?
        private let session: Int64

        init(deviceID: String?, sessionID: Int64) {
            self.device = deviceID
            self.session = sessionID
        }

        func deviceID() -> String? { device }
        func sessionID() -> Int64 { session }
    }

    func occurrence(id: Int, at milliseconds: Int64) -> AnalyticsEventOccurrence {
        AnalyticsEventOccurrence(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            occurredAt: Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
        )
    }

    func storedLogs(in storage: ServerLogStorage) async throws -> [[String: Any]] {
        try await storage.events().map { event in
            try #require(try JSONSerialization.jsonObject(with: event.log) as? [String: Any])
        }
    }

    struct Fixture {
        let repository: ServerAnalyticsRepository
        let pipeline: ServerLogPipeline
        let storage: ServerLogStorage
        let sessionStore: ServerLogSessionStore
        let session: ScriptedURLSession
        let now: NowStub
    }

    func withRepository(
        identity: IdentityStub,
        operation: (ServerAnalyticsRepository, ServerLogStorage, ServerLogSessionStore, NowStub) async throws -> Void
    ) async throws {
        try await withFixture(identity: identity) { fixture in
            try await operation(fixture.repository, fixture.storage, fixture.sessionStore, fixture.now)
        }
    }

    func withFixture(identity: IdentityStub, operation: (Fixture) async throws -> Void) async throws {
        let directory = makeTemporaryDirectory()
        let suiteName = "ServerAnalyticsRepositoryTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suiteName)
        }
        let now = NowStub(0)
        let session = ScriptedURLSession { _ in 503 }
        let storage = ServerLogStorage(directory: directory)
        let pipeline = ServerLogPipeline(
            storage: storage,
            client: ServerLogHttpClient(session: session),
            tokenReader: AccessTokenReaderStub(token: nil),
            backgroundTask: BackgroundTaskStub(),
            configuration: .test(),
            now: { now.value },
            jitter: { _ in .zero }
        )
        let sessionStore = ServerLogSessionStore(defaults: defaults)
        let repository = ServerAnalyticsRepository(
            identity: identity,
            pipeline: pipeline,
            sessionStore: sessionStore,
            observesLifecycle: false,
            now: { now.value },
            isApplicationActive: { false },
            makeContext: { ServerLogContext(appVersion: "1.2.9", values: ["osName": "ios"]) }
        )
        let fixture = Fixture(
            repository: repository,
            pipeline: pipeline,
            storage: storage,
            sessionStore: sessionStore,
            session: session,
            now: now
        )
        do {
            try await operation(fixture)
        } catch {
            await pipeline.stop()
            throw error
        }
        await pipeline.stop()
    }
}
