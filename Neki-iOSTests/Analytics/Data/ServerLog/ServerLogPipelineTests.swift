//
//  ServerLogPipelineTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerLogPipelineTests {
    @Test("기준 수만큼 쌓이면 보내고, 접수된 로그는 지운다")
    func put_whenReachingThreshold_uploadsAndRemoves() async throws {
        let session = ScriptedURLSession { _ in 200 }
        try await withPipeline(session: session, configuration: .test(flushEventCount: 2)) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            await pipeline.waitForUpload()
            let requestCountBeforeThreshold = session.requests.count

            try await pipeline.put(makeServerLogStoredEvent(id: "b", occurredAt: 2_000))
            await pipeline.waitForUpload()

            #expect(requestCountBeforeThreshold == 0)
            #expect(session.requests.map(\.logEventIDs) == [["a", "b"]])
            #expect(await storage.events().isEmpty)
        }
    }

    @Test("실행 직후 start는 타이머만 켜고 바로 보내지 않는다")
    func start_doesNotSendImmediately() async throws {
        let session = ScriptedURLSession { _ in 200 }
        try await withPipeline(session: session) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))

            await pipeline.start()
            await pipeline.waitForUpload()

            #expect(session.requests.isEmpty)
            #expect(await storage.events().map(\.eventID) == ["a"])
        }
    }

    @Test("회원마다 배치를 나누고, 지금 로그인한 회원이 남긴 로그에만 토큰을 붙인다")
    func flush_splitsBatchesByUserAndAuthorizesCurrentUserOnly() async throws {
        let session = ScriptedURLSession { _ in 200 }
        try await withPipeline(session: session) { pipeline, _ in
            await pipeline.updateCurrentUserID("1")
            for (index, userID) in ["1", "1", nil, "2"].enumerated() {
                try await pipeline.put(makeServerLogStoredEvent(id: "e\(index)", occurredAt: Int64(index) * 1_000, userID: userID))
            }

            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.map(\.logEventIDs) == [["e0", "e1"], ["e2"], ["e3"]])
            #expect(session.requests.map(\.authorization) == ["Bearer token", nil, nil])
        }
    }

    @Test("413이면 반으로 나눠 보내고, 한 건만 남아도 받지 않으면 그 로그를 버린다")
    func flush_whenTooLarge_splitsAndDropsSingleLog() async throws {
        let session = ScriptedURLSession { request in request.logEventIDs.contains("big") ? 413 : 200 }
        try await withPipeline(session: session) { pipeline, storage in
            for (index, id) in ["big", "a", "b"].enumerated() {
                try await pipeline.put(makeServerLogStoredEvent(id: id, occurredAt: Int64(index) * 1_000))
            }

            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.map(\.logEventIDs) == [["big", "a", "b"], ["big"], ["a", "b"]])
            #expect(await storage.events().isEmpty)
        }
    }

    @Test("400이면 반씩 나눠 받지 않는 로그만 버리고 나머지는 보낸다")
    func flush_whenInvalid_bisectsToInvalidLog() async throws {
        let session = ScriptedURLSession { request in request.logEventIDs.contains("bad") ? 400 : 200 }
        try await withPipeline(session: session) { pipeline, storage in
            for (index, id) in ["a", "b", "bad", "c"].enumerated() {
                try await pipeline.put(makeServerLogStoredEvent(id: id, occurredAt: Int64(index) * 1_000))
            }

            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.map(\.logEventIDs) == [["a", "b", "bad", "c"], ["a", "b"], ["bad", "c"], ["bad"], ["c"]])
            #expect(await storage.events().isEmpty)
        }
    }

    @Test("200이라도 D-0을 확인하지 못하면 지우지 않고 나중에 다시 보낸다", arguments: ["D-15", nil] as [String?])
    func flush_whenSuccessIsUnconfirmed_keepsLogs(resultCode: String?) async throws {
        let session = ScriptedURLSession(resultCode: { _ in resultCode }) { _ in 200 }
        try await withPipeline(session: session) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))

            await pipeline.flushAndWait(timeout: .seconds(5))
            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.map(\.logEventIDs) == [["a"], ["a"]])
            #expect(await storage.events().map(\.eventID) == ["a"])
        }
    }

    @Test("401·403이면 토큰만 빼고 같은 본문을 바로 다시 보낸다", arguments: [401, 403])
    func flush_whenUnauthorized_retriesWithoutToken(statusCode: Int) async throws {
        let session = ScriptedURLSession { request in request.authorization == nil ? 200 : statusCode }
        try await withPipeline(session: session) { pipeline, storage in
            await pipeline.updateCurrentUserID("1")
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            try await pipeline.put(makeServerLogStoredEvent(id: "b", occurredAt: 2_000))

            await pipeline.flushAndWait(timeout: .seconds(5))
            let requests = session.requests

            #expect(requests.map(\.authorization) == ["Bearer token", nil])
            #expect(requests[0].httpBody == requests[1].httpBody)
            #expect(await storage.events().isEmpty)
        }
    }

    @Test("보내지 못하면 남겨 두고, 대기 시간 전에는 쌓인 수만으로 다시 보내지 않는다")
    func flush_whenUnavailable_keepsLogsAndWaitsForRetryDelay() async throws {
        let session = ScriptedURLSession { _ in 503 }
        try await withPipeline(session: session, configuration: .test(flushEventCount: 1)) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            await pipeline.waitForUpload()
            try await pipeline.put(makeServerLogStoredEvent(id: "b", occurredAt: 2_000))
            await pipeline.waitForUpload()
            let requestCountDuringRetryDelay = session.requests.count

            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(requestCountDuringRetryDelay == 1)
            #expect(session.requests.map(\.logEventIDs) == [["a"], ["a", "b"]])
            #expect(await storage.events().map(\.eventID) == ["a", "b"])
        }
    }

    @Test("업로드를 기다리는 동안 탈퇴로 지운 로그는 이미 읽은 목록에 있어도 보내지 않는다")
    func upload_skipsLogsRemovedWhileUploading() async throws {
        let holder = PipelineHolder()
        let session = ScriptedURLSession { request in
            if request.logEventIDs == ["e0"], let pipeline = holder.pipeline {
                await pipeline.removeEvents(userID: "2")
            }
            return 200
        }
        try await withPipeline(session: session) { pipeline, storage in
            holder.pipeline = pipeline
            try await pipeline.put(makeServerLogStoredEvent(id: "e0", occurredAt: 1_000, userID: "1"))
            try await pipeline.put(makeServerLogStoredEvent(id: "e1", occurredAt: 2_000, userID: "2"))

            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.map(\.logEventIDs) == [["e0"]])
            #expect(await storage.events().isEmpty)
        }
    }

    @Test("다시 보내기까지의 대기 시간은 1초부터 두 배씩 늘어 5분에서 멈춘다")
    func retryDelay_growsExponentiallyUpToFiveMinutes() {
        let delays = (1...11).map { ServerLogPipeline.retryDelay(failureCount: $0, configuration: .init()) }

        #expect(delays == [1, 2, 4, 8, 16, 32, 64, 128, 256, 300, 300].map { Duration.seconds($0) })
    }

    @Test("탈퇴한 회원이 남긴 로그만 지운다")
    func removeEvents_removesOnlyGivenUser() async throws {
        try await withPipeline(session: ScriptedURLSession { _ in 503 }) { pipeline, storage in
            for (index, userID) in ["1", "2", "1", nil].enumerated() {
                try await pipeline.put(makeServerLogStoredEvent(id: "e\(index)", occurredAt: Int64(index) * 1_000, userID: userID))
            }

            await pipeline.removeEvents(userID: "1")

            #expect(await storage.events().map(\.eventID) == ["e1", "e3"])
        }
    }

    @Test("업로드가 끝나지 않아도 정한 시간까지만 기다린다")
    func flushAndWait_returnsAfterTimeout() async throws {
        let session = ScriptedURLSession { _ in
            try await Task.sleep(for: .seconds(10))
            return 200
        }
        try await withPipeline(session: session) { pipeline, _ in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            let clock = ContinuousClock()
            let start = clock.now

            await pipeline.flushAndWait(timeout: .milliseconds(100))

            #expect(clock.now - start < .seconds(5))
        }
    }

    @Test("저장된 토큰이 없거나 만료 5분 전부터는 토큰 없이 보낸다")
    func storedTokenReader_returnsOnlyUsableToken() async throws {
        let fresh = AuthTokens(accessToken: "fresh", refreshToken: "refresh")
        let expiringJSON = #"{"accessToken":"expiring","refreshToken":"refresh","expiredAt":\#(Date().addingTimeInterval(60).timeIntervalSinceReferenceDate)}"#
        let expiring = try JSONDecoder().decode(AuthTokens.self, from: Data(expiringJSON.utf8))

        let freshToken = await ServerLogStoredTokenReader(reader: StoredTokenStub(result: .success(fresh))).usableAccessToken()
        let expiringToken = await ServerLogStoredTokenReader(reader: StoredTokenStub(result: .success(expiring))).usableAccessToken()
        let missingToken = await ServerLogStoredTokenReader(reader: StoredTokenStub(result: .failure(TokenStorageError.notFound))).usableAccessToken()

        #expect(freshToken == "fresh")
        #expect(expiringToken == nil)
        #expect(missingToken == nil)
    }

    @Test("업로드마다 background task를 시작하고, 보내지 못해도 끝낸다")
    func upload_beginsAndEndsBackgroundTaskEachTime() async throws {
        let session = ScriptedURLSession { request in request.logEventIDs.contains("fail") ? 503 : 200 }
        let backgroundTask = BackgroundTaskRecorder()
        try await withPipeline(session: session, backgroundTask: backgroundTask) { pipeline, _ in
            try await pipeline.put(makeServerLogStoredEvent(id: "ok", occurredAt: 1_000))
            await pipeline.flushAndWait(timeout: .seconds(5))
            try await pipeline.put(makeServerLogStoredEvent(id: "fail", occurredAt: 2_000))
            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.map(\.logEventIDs) == [["ok"], ["fail"]])
            #expect(backgroundTask.beganCount == 2)
            #expect(backgroundTask.endedCount == 2)
        }
    }

    @Test("네트워크 경로가 끊긴 동안에는 쌓인 수·탈퇴 전 전송으로도 보내지 않고 저장만 한다")
    func flush_whilePathUnsatisfied_storesOnly() async throws {
        let session = ScriptedURLSession { _ in 200 }
        try await withPipeline(session: session, configuration: .test(flushEventCount: 1)) { pipeline, storage in
            await pipeline.networkPathChanged(isSatisfied: false)

            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            await pipeline.waitForUpload()
            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.isEmpty)
            #expect(await storage.events().map(\.eventID) == ["a"])
        }
    }

    @Test("경로가 이어진 채로 알림만 오면 보내지 않는다(실행 직후 첫 알림 포함)")
    func networkPathChanged_whileOnline_doesNotSend() async throws {
        let session = ScriptedURLSession { _ in 200 }
        try await withPipeline(session: session) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))

            await pipeline.networkPathChanged(isSatisfied: true)
            await pipeline.waitForUpload()

            #expect(session.requests.isEmpty)
            #expect(await storage.events().map(\.eventID) == ["a"])
        }
    }

    @Test("start 뒤 경로가 끊겼다 다시 이어지면 쌓인 로그를 바로 보낸다")
    func start_whenPathRestored_sendsStoredLogs() async throws {
        let session = ScriptedURLSession { _ in 200 }
        let networkPath = NetworkPathStub()
        try await withPipeline(session: session, networkPath: networkPath) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            try await pipeline.put(makeServerLogStoredEvent(id: "b", occurredAt: 2_000))
            await pipeline.start()

            networkPath.send(isSatisfied: false)
            networkPath.send(isSatisfied: true)

            #expect(await eventually { session.requests.count == 1 })
            await pipeline.waitForUpload()
            #expect(session.requests.map(\.logEventIDs) == [["a", "b"]])
            #expect(await storage.events().isEmpty)
        }
    }

    @Test("경로가 끊기면 기다리던 재시도를 취소한다")
    func networkPathChanged_whenUnsatisfied_cancelsPendingRetry() async throws {
        var configuration = ServerLogPipeline.Configuration.test()
        configuration.minimumRetryDelay = .milliseconds(100)
        configuration.maximumRetryDelay = .milliseconds(100)
        let counter = RequestCounter()
        let session = ScriptedURLSession { _ in counter.next() == 1 ? 503 : 200 }
        try await withPipeline(session: session, configuration: configuration) { pipeline, _ in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            await pipeline.flushAndWait(timeout: .seconds(5))
            await pipeline.networkPathChanged(isSatisfied: false)
            await pipeline.networkPathChanged(isSatisfied: true)
            await pipeline.waitForUpload()

            // 취소하지 않았다면 첫 실패 뒤 100ms에 걸어 둔 재시도가 이 로그를 보냅니다.
            try await pipeline.put(makeServerLogStoredEvent(id: "b", occurredAt: 2_000))
            try await Task.sleep(for: .milliseconds(300))

            #expect(session.requests.map(\.logEventIDs) == [["a"], ["a"]])
        }
    }

    @Test("연결 오류는 첫 실패에 멈추고, 경로가 바뀌면 한 번 보낸다")
    func upload_whenConnectionFails_pausesUntilPathChanges() async throws {
        let counter = RequestCounter()
        let session = ScriptedURLSession { _ in
            if counter.next() == 1 { throw URLError(.notConnectedToInternet) }
            return 200
        }
        try await withPipeline(session: session) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            await pipeline.flushAndWait(timeout: .seconds(5))
            await pipeline.flushAndWait(timeout: .seconds(5))
            let requestCountWhilePaused = session.requests.count

            await pipeline.networkPathChanged(isSatisfied: true)
            await pipeline.waitForUpload()

            #expect(requestCountWhilePaused == 1)
            #expect(session.requests.count == 2)
            #expect(await storage.events().isEmpty)
        }
    }

    @Test("연결 오류가 아니어도 7번 연속 실패하면 멈추고, 경로가 바뀌어 다시 보낸 한 번이 실패하면 바로 다시 멈춘다")
    func upload_afterSevenFailures_pausesUntilPathChanges() async throws {
        let session = ScriptedURLSession { _ in 503 }
        try await withPipeline(session: session) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            for _ in 1...8 {
                await pipeline.flushAndWait(timeout: .seconds(5))
            }
            let requestCountAfterPause = session.requests.count

            await pipeline.networkPathChanged(isSatisfied: true)
            await pipeline.waitForUpload()
            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(requestCountAfterPause == 7)
            #expect(session.requests.count == 8)
            #expect(await storage.events().map(\.eventID) == ["a"])
        }
    }

    @Test("멈춘 뒤 다시 보내 성공하면 실패 횟수를 0으로 되돌려, 다음 실패에는 멈추지 않는다")
    func upload_afterPause_resetsFailureCountOnSuccess() async throws {
        let counter = RequestCounter()
        let session = ScriptedURLSession { _ in counter.next() == 8 ? 200 : 503 }
        try await withPipeline(session: session) { pipeline, storage in
            try await pipeline.put(makeServerLogStoredEvent(id: "a", occurredAt: 1_000))
            for _ in 1...7 {
                await pipeline.flushAndWait(timeout: .seconds(5))
            }
            await pipeline.networkPathChanged(isSatisfied: true)
            await pipeline.waitForUpload()

            try await pipeline.put(makeServerLogStoredEvent(id: "b", occurredAt: 2_000))
            await pipeline.flushAndWait(timeout: .seconds(5))
            await pipeline.flushAndWait(timeout: .seconds(5))

            #expect(session.requests.map(\.logEventIDs) == Array(repeating: ["a"], count: 8) + [["b"], ["b"]])
            #expect(await storage.events().map(\.eventID) == ["b"])
        }
    }
}


// MARK: - Helpers

private final class PipelineHolder: @unchecked Sendable {
    var pipeline: ServerLogPipeline?
}

/// 받은 요청이 몇 번째인지(1부터) 셉니다.
private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func next() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}

private extension ServerLogPipelineTests {
    struct StoredTokenStub: StoredAuthTokenReading {
        let result: Result<AuthTokens, any Error>

        func fetchStoredTokens() async throws -> AuthTokens {
            try result.get()
        }
    }

    func withPipeline(
        session: ScriptedURLSession,
        configuration: ServerLogPipeline.Configuration = .test(),
        backgroundTask: any ServerLogBackgroundTaskStarting = BackgroundTaskStub(),
        networkPath: any NetworkPathObserving = NetworkPathStub(),
        operation: (ServerLogPipeline, ServerLogStorage) async throws -> Void
    ) async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = ServerLogStorage(directory: directory)
        let pipeline = ServerLogPipeline(
            storage: storage,
            client: ServerLogHttpClient(session: session),
            tokenReader: AccessTokenReaderStub(token: "token"),
            backgroundTask: backgroundTask,
            networkPath: networkPath,
            configuration: configuration,
            now: { 10_000 },
            jitter: { _ in .zero }
        )
        do {
            try await operation(pipeline, storage)
        } catch {
            await pipeline.stop()
            throw error
        }
        await pipeline.stop()
    }
}
