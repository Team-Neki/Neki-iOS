//
//  ServerLogTestDoubles.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
@testable import Neki_iOS

/// 요청을 기록하고, 요청마다 정한 상태 코드로 답하는 세션. 결과 코드를 따로 정하지 않으면 계약대로 붙입니다.
final class ScriptedURLSession: URLSessionProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let responder: @Sendable (URLRequest) async throws -> Int
    private let resultCode: @Sendable (Int) -> String?
    private var recordedRequests: [URLRequest] = []

    /// - Parameter resultCode: 상태 코드에 붙일 결과 코드. `nil`이면 본문에 넣지 않습니다.
    init(
        resultCode: @escaping @Sendable (Int) -> String? = ScriptedURLSession.contractResultCode(for:),
        responder: @escaping @Sendable (URLRequest) async throws -> Int
    ) {
        self.responder = responder
        self.resultCode = resultCode
    }

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        lock.withLock { recordedRequests.append(request) }
        let statusCode = try await responder(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        let body = resultCode(statusCode).map { #"{"resultCode":"\#($0)","message":""}"# } ?? #"{"message":""}"#
        return (Data(body.utf8), response)
    }

    /// 계약의 결과 코드: 200 D-0, 400 D-01, 413 D-16, 503 D-15
    static func contractResultCode(for statusCode: Int) -> String? {
        switch statusCode {
        case 200: return "D-0"
        case 400: return "D-01"
        case 413: return "D-16"
        case 503: return "D-15"
        default: return nil
        }
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

/// background task를 시작하고 끝낸 횟수를 셉니다.
final class BackgroundTaskRecorder: ServerLogBackgroundTaskStarting, @unchecked Sendable {
    private let lock = NSLock()
    private var began = 0
    private var ended = 0

    var beganCount: Int {
        lock.withLock { began }
    }

    var endedCount: Int {
        lock.withLock { ended }
    }

    func begin() async -> @Sendable () async -> Void {
        lock.withLock { began += 1 }
        return { self.lock.withLock { self.ended += 1 } }
    }
}

/// 테스트가 보내는 생명주기 변화를 그대로 넘기는 대역
struct ApplicationLifecycleStub: ApplicationLifecycleObserving {
    private let active: Bool
    private let stream: AsyncStream<ApplicationLifecycleEvent>
    private let continuation: AsyncStream<ApplicationLifecycleEvent>.Continuation

    init(isActive: Bool = false) {
        let (stream, continuation) = AsyncStream.makeStream(of: ApplicationLifecycleEvent.self)
        self.active = isActive
        self.stream = stream
        self.continuation = continuation
    }

    func isActive() async -> Bool {
        active
    }

    func events() -> AsyncStream<ApplicationLifecycleEvent> {
        stream
    }

    func send(_ event: ApplicationLifecycleEvent) {
        continuation.yield(event)
    }
}

/// 테스트가 보내는 네트워크 경로 변화를 그대로 넘기는 대역
struct NetworkPathStub: NetworkPathObserving {
    private let stream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        self.stream = stream
        self.continuation = continuation
    }

    func updates() -> AsyncStream<Bool> {
        stream
    }

    func send(isSatisfied: Bool) {
        continuation.yield(isSatisfied)
    }
}

/// 다른 Task가 처리하는 일을 조건이 맞을 때까지 잠깐씩 기다립니다. 시간 안에 맞으면 `true`
func eventually(timeout: Duration = .seconds(2), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
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
