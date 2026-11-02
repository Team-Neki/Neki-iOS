//
//  ServerLogTestDoubles.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
@testable import Neki_iOS

/// 요청을 기록하고, 요청마다 정한 상태 코드로 답하는 세션
final class ScriptedURLSession: URLSessionProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let responder: @Sendable (URLRequest) async throws -> Int
    private var recordedRequests: [URLRequest] = []

    init(responder: @escaping @Sendable (URLRequest) async throws -> Int) {
        self.responder = responder
    }

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        lock.withLock { recordedRequests.append(request) }
        let statusCode = try await responder(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"resultCode":"D-0","message":""}"#.utf8), response)
    }
}

extension URLRequest {
    /// 본문 `logs`에 담긴 로그의 `eventId`
    var logEventIDs: [String] {
        guard let httpBody,
              let object = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any],
              let logs = object["logs"] as? [[String: Any]]
        else { return [] }
        return logs.compactMap { $0["eventId"] as? String }
    }

    var authorization: String? {
        value(forHTTPHeaderField: "Authorization")
    }
}

struct AccessTokenReaderStub: ServerLogAccessTokenReading {
    let token: String?

    func usableAccessToken() async -> String? {
        token
    }
}

struct BackgroundTaskStub: ServerLogBackgroundTaskStarting {
    func begin() async -> @Sendable () async -> Void {
        {}
    }
}

/// 테스트가 정하는 현재 시각(epoch ms)
final class NowStub: @unchecked Sendable {
    private let lock = NSLock()
    private var milliseconds: Int64

    init(_ milliseconds: Int64) {
        self.milliseconds = milliseconds
    }

    var value: Int64 {
        get { lock.withLock { milliseconds } }
        set { lock.withLock { milliseconds = newValue } }
    }
}

extension ServerLogPipeline.Configuration {
    /// 타이머와 자동 재시도가 테스트 중에 끼어들지 않는 설정
    static func test(flushEventCount: Int = 1_000) -> Self {
        var configuration = Self()
        configuration.flushEventCount = flushEventCount
        configuration.flushInterval = .seconds(3_600)
        configuration.minimumRetryDelay = .seconds(3_600)
        configuration.maximumRetryDelay = .seconds(3_600)
        return configuration
    }
}

func makeServerLogStoredEvent(id: String, occurredAt: Int64, userID: String? = "1") -> ServerLogStoredEvent {
    let event = ServerLogEvent(
        eventID: id,
        eventType: "app_open",
        eventProperties: [:],
        occurredAtMilliseconds: occurredAt,
        sessionID: occurredAt,
        sequenceNumber: 1,
        deviceID: "device-1",
        userIDAtOccurrence: userID,
        appVersion: "1.2.9",
        context: [:]
    )
    return ServerLogStoredEvent(event: event, log: Data(#"{"eventId":"\#(id)"}"#.utf8))
}

func makeTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("ServerLogTests-\(UUID().uuidString)", isDirectory: true)
}
