//
//  DefaultNetworkProviderFileTransferTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 10/29/26.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Neki_iOS

@Suite(.serialized)
struct DefaultNetworkProviderFileTransferTests {
    @Test("허용하지 않은 MIME 응답은 파일에 기록하지 않는다")
    func requestWritingTo_rejectsUnsupportedMIMEType() async throws {
        let response = try makeResponse(contentType: "video/mp4")
        URLProtocolStub.prepare(response: response, data: Data(repeating: 0x01, count: 16))
        let fileURL = try makeEmptyTemporaryFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let provider = makeProvider()

        await #expect(throws: NetworkError.self) {
            try await provider.request(endpoint: makeEndpoint(maximumBodySize: 32), writingTo: fileURL)
        }

        #expect(try Data(contentsOf: fileURL).isEmpty)
    }

    @Test("HTML 관련 타입이어도 text/html과 동일하지 않으면 거부한다")
    func requestWritingTo_rejectsNonEquivalentHTMLType() async throws {
        let response = try makeResponse(contentType: "application/xhtml+xml")
        URLProtocolStub.prepare(response: response, data: Data("<html></html>".utf8))
        let fileURL = try makeEmptyTemporaryFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let provider = makeProvider()

        await #expect(throws: NetworkError.self) {
            try await provider.request(endpoint: makeEndpoint(maximumBodySize: 32), writingTo: fileURL)
        }

        #expect(try Data(contentsOf: fileURL).isEmpty)
    }

    @Test("선언된 응답 크기가 상한을 넘으면 파일에 기록하지 않는다")
    func requestWritingTo_rejectsDeclaredOversizedResponse() async throws {
        let response = try makeResponse(contentType: "text/html; charset=utf-8", contentLength: 16)
        URLProtocolStub.prepare(
            response: response,
            data: Data(repeating: 0x61, count: 16),
            chunkSize: 4,
            chunkDelay: 0.01
        )
        let fileURL = try makeEmptyTemporaryFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let provider = makeProvider()

        await #expect(throws: NetworkError.self) {
            try await provider.request(endpoint: makeEndpoint(maximumBodySize: 8), writingTo: fileURL)
        }

        await URLProtocolStub.waitForStopLoading()
        #expect(try Data(contentsOf: fileURL).isEmpty)
        #expect(URLProtocolStub.deliveredByteCount == 0)
        #expect(URLProtocolStub.didStopLoading)
    }

    @Test("길이를 알 수 없는 응답은 실제 바이트가 상한을 넘는 즉시 중단한다")
    func requestWritingTo_rejectsActualOversizedResponse() async throws {
        let response = try makeResponse(contentType: "text/html; charset=utf-8")
        let payload = Data(repeating: 0x61, count: 1_024)
        URLProtocolStub.prepare(
            response: response,
            data: payload,
            chunkSize: 4,
            chunkDelay: 0.01
        )
        let fileURL = try makeEmptyTemporaryFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let provider = makeProvider()

        await #expect(throws: NetworkError.self) {
            try await provider.request(endpoint: makeEndpoint(maximumBodySize: 8), writingTo: fileURL)
        }

        await URLProtocolStub.waitForStopLoading()
        #expect(try Data(contentsOf: fileURL).isEmpty)
        #expect(URLProtocolStub.deliveredByteCount < payload.count)
        #expect(URLProtocolStub.didStopLoading)
    }

    @Test("검증을 통과한 HTML 응답을 완전한 파일로 기록한다")
    func requestWritingTo_writesCompleteHTML() async throws {
        let htmlData = Data("<html></html>".utf8)
        let response = try makeResponse(contentType: "text/html; charset=utf-8")
        URLProtocolStub.prepare(response: response, data: htmlData)
        let fileURL = try makeEmptyTemporaryFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let provider = makeProvider()

        _ = try await provider.request(endpoint: makeEndpoint(maximumBodySize: Int64(htmlData.count)), writingTo: fileURL)

        #expect(try Data(contentsOf: fileURL) == htmlData)
    }

    @Test("기존 파일을 재사용해도 이전 파일의 잔여 바이트를 남기지 않는다")
    func requestWritingTo_truncatesExistingFile() async throws {
        let htmlData = Data("<html></html>".utf8)
        let response = try makeResponse(contentType: "text/html; charset=utf-8")
        URLProtocolStub.prepare(response: response, data: htmlData)
        let fileURL = try makeEmptyTemporaryFile()
        try Data(repeating: 0x61, count: htmlData.count * 2).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let provider = makeProvider()

        _ = try await provider.request(endpoint: makeEndpoint(maximumBodySize: Int64(htmlData.count)), writingTo: fileURL)

        #expect(try Data(contentsOf: fileURL) == htmlData)
    }
}

private extension DefaultNetworkProviderFileTransferTests {
    func makeProvider() -> DefaultNetworkProvider {
        let session = makeSession()
        return DefaultNetworkProvider(
            session: session,
            credentialBroker: DefaultNetworkCredentialBroker()
        ) { _, _ in }
    }

    func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    func makeEndpoint(maximumBodySize: Int64) -> FileDownloadEndpointStub {
        FileDownloadEndpointStub(responseConstraint: HTTPResponseConstraint(allowedContentTypes: [.html], maximumBodySize: maximumBodySize))
    }

    func makeResponse(contentType: String, contentLength: Int? = nil) throws -> HTTPURLResponse {
        var headers = ["Content-Type": contentType]
        if let contentLength { headers["Content-Length"] = String(contentLength) }
        return try #require(HTTPURLResponse(
            url: FileDownloadEndpointStub.url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        ))
    }

    func makeEmptyTemporaryFile() throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return fileURL
    }
}

private struct FileDownloadEndpointStub: FileDownloadEndpoint {
    static let url = URL(string: "https://example.com/dump")!

    let responseConstraint: HTTPResponseConstraint
    let contentType: HTTPContentType = .json
    let baseURL = Self.url.absoluteString
    let path = ""
    let method: HTTPMethodType = .get
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
            Self.response.map { ($0, Self.data, Self.chunkSize, Self.chunkDelay) }
        }
        guard let configuration else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data, chunkSize, chunkDelay) = configuration
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        DispatchQueue.global(qos: .utility).async { [self] in
            var offset = 0
            while offset < data.count {
                guard Self.lock.withLock({ Self.isStopped == false }) else { return }
                if chunkDelay > 0 { Thread.sleep(forTimeInterval: chunkDelay) }
                guard Self.lock.withLock({ Self.isStopped == false }) else { return }

                let endOffset = min(offset + chunkSize, data.count)
                let chunk = data[offset..<endOffset]
                client?.urlProtocol(self, didLoad: Data(chunk))
                Self.lock.withLock { Self._deliveredByteCount += chunk.count }
                offset = endOffset
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        Self.lock.withLock {
            Self.isStopped = true
            Self._didStopLoading = true
        }
    }
}
