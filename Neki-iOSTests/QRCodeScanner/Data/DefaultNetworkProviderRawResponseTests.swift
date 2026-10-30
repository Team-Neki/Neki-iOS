//
//  DefaultNetworkProviderRawResponseTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 10/30/26.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Neki_iOS

@Suite(.serialized)
struct DefaultNetworkProviderRawResponseTests {
    @Test("허용하지 않은 MIME 응답은 수신하지 않는다")
    func request_rejectsUnsupportedMIMEType() async throws {
        let response = try makeResponse(contentType: "video/mp4")
        URLProtocolStub.prepare(response: response, data: Data(repeating: 0x01, count: 16))
        let provider = makeProvider()

        await #expect(throws: NetworkError.self) {
            let _: (data: Data, response: HTTPURLResponse) = try await provider.request(
                endpoint: makeEndpoint(maximumBodySize: 32)
            )
        }

        #expect(URLProtocolStub.deliveredByteCount == 0)
    }

    @Test("선언된 응답 크기가 상한을 넘으면 body를 수신하지 않는다")
    func request_rejectsDeclaredOversizedResponse() async throws {
        let response = try makeResponse(contentType: "text/html; charset=utf-8", contentLength: 16)
        URLProtocolStub.prepare(
            response: response,
            data: Data(repeating: 0x61, count: 16),
            chunkSize: 4,
            chunkDelay: 0.01
        )
        let provider = makeProvider()

        await #expect(throws: NetworkError.self) {
            let _: (data: Data, response: HTTPURLResponse) = try await provider.request(
                endpoint: makeEndpoint(maximumBodySize: 8)
            )
        }

        await URLProtocolStub.waitForStopLoading()
        #expect(URLProtocolStub.deliveredByteCount == 0)
        #expect(URLProtocolStub.didStopLoading)
    }

    @Test("길이를 알 수 없는 응답은 실제 수신량이 상한을 넘으면 중단한다")
    func request_rejectsActualOversizedResponse() async throws {
        let response = try makeResponse(contentType: "text/html; charset=utf-8")
        let payload = Data(repeating: 0x61, count: 1_024)
        URLProtocolStub.prepare(
            response: response,
            data: payload,
            chunkSize: 4,
            chunkDelay: 0.01
        )
        let provider = makeProvider()

        await #expect(throws: NetworkError.self) {
            let _: (data: Data, response: HTTPURLResponse) = try await provider.request(
                endpoint: makeEndpoint(maximumBodySize: 8)
            )
        }

        await URLProtocolStub.waitForStopLoading()
        #expect(URLProtocolStub.deliveredByteCount < payload.count)
        #expect(URLProtocolStub.didStopLoading)
    }

    @Test("검증을 통과한 HTML 원문을 반환한다")
    func request_returnsHTMLData() async throws {
        let htmlData = Data("<html></html>".utf8)
        let response = try makeResponse(contentType: "text/html; charset=utf-8")
        URLProtocolStub.prepare(response: response, data: htmlData)
        let provider = makeProvider()

        let result: (data: Data, response: HTTPURLResponse) = try await provider.request(
            endpoint: makeEndpoint(maximumBodySize: Int64(htmlData.count))
        )

        #expect(result.data == htmlData)
        #expect(result.response.url == response.url)
    }
}

private extension DefaultNetworkProviderRawResponseTests {
    func makeProvider() -> DefaultNetworkProvider {
        DefaultNetworkProvider(
            session: makeSession(),
            credentialBroker: DefaultNetworkCredentialBroker()
        ) { _, _ in }
    }

    func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    func makeEndpoint(maximumBodySize: Int64) -> RawResponseEndpointStub {
        RawResponseEndpointStub(
            responseConstraint: HTTPResponseConstraint(
                allowedContentTypes: [.html],
                maximumBodySize: maximumBodySize
            )
        )
    }

    func makeResponse(contentType: String, contentLength: Int? = nil) throws -> HTTPURLResponse {
        var headers = ["Content-Type": contentType]
        if let contentLength { headers["Content-Length"] = String(contentLength) }
        return try #require(HTTPURLResponse(
            url: RawResponseEndpointStub.url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        ))
    }
}

private struct RawResponseEndpointStub: Endpoint {
    static let url = URL(string: "https://example.com/dump")!

    let responseConstraint: HTTPResponseConstraint?
    let contentType: HTTPContentType = .json
    let baseURL = Self.url.absoluteString
    let path = ""
    let method: HTTPMethodType = .get
    let authorizationType: AuthorizationType = .none
    let body: (any Encodable)? = nil
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var response: HTTPURLResponse?
    private static var data = Data()
    private static var chunkSize = 0
    private static var chunkDelay: TimeInterval = 0
    private static var isStopped = false
    private static var _deliveredByteCount = 0
    private static var _didStopLoading = false
    private static var generation = 0
    private var deliveryTask: Task<Void, Never>?
    private var requestGeneration: Int?

    static var deliveredByteCount: Int {
        lock.withLock { _deliveredByteCount }
    }

    static var didStopLoading: Bool {
        lock.withLock { _didStopLoading }
    }

    static func prepare(
        response: HTTPURLResponse,
        data: Data,
        chunkSize: Int? = nil,
        chunkDelay: TimeInterval = 0
    ) {
        lock.withLock {
            self.response = response
            self.data = data
            self.chunkSize = chunkSize ?? data.count
            self.chunkDelay = chunkDelay
            isStopped = false
            _deliveredByteCount = 0
            _didStopLoading = false
            generation += 1
        }
    }

    static func waitForStopLoading() async {
        for _ in 0..<100 {
            guard didStopLoading == false else { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let configuration = Self.lock.withLock {
            Self.response.map { ($0, Self.data, Self.chunkSize, Self.chunkDelay, Self.generation) }
        }
        guard let configuration else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data, chunkSize, chunkDelay, generation) = configuration
        requestGeneration = generation
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        deliveryTask = Task.detached(priority: .utility) { [self] in
            var offset = 0
            while offset < data.count {
                guard Self.shouldContinue(generation: generation) else { return }
                if chunkDelay > 0 { try? await Task.sleep(for: .seconds(chunkDelay)) }
                guard Self.shouldContinue(generation: generation) else { return }

                let endOffset = min(offset + chunkSize, data.count)
                let chunk = data[offset..<endOffset]
                client?.urlProtocol(self, didLoad: Data(chunk))
                Self.lock.withLock {
                    guard Self.generation == generation else { return }
                    Self._deliveredByteCount += chunk.count
                }
                offset = endOffset
            }
            guard Self.shouldContinue(generation: generation) else { return }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        deliveryTask?.cancel()
        Self.lock.withLock {
            guard requestGeneration == Self.generation else { return }
            Self.isStopped = true
            Self._didStopLoading = true
        }
    }

    private static func shouldContinue(generation: Int) -> Bool {
        lock.withLock { self.generation == generation && isStopped == false }
    }
}
