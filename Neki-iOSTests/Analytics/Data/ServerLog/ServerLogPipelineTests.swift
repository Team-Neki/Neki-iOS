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
}


// MARK: - Helpers

private final class PipelineHolder: @unchecked Sendable {
    var pipeline: ServerLogPipeline?
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
        operation: (ServerLogPipeline, ServerLogStorage) async throws -> Void
    ) async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = ServerLogStorage(directory: directory)
        let pipeline = ServerLogPipeline(
            storage: storage,
            client: ServerLogHttpClient(session: session),
            tokenReader: AccessTokenReaderStub(token: "token"),
            backgroundTask: BackgroundTaskStub(),
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
