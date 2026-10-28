//
//  DefaultQRCodeDumpRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 10/28/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct DefaultQRCodeDumpRepositoryTests {
    @Test("HTML main document와 redirect 최종 URL을 보존한다")
    func fetchHTMLDocument_preservesHTMLAndFinalURL() async throws {
        let sourceURL = try #require(URL(string: "https://example.com/qr"))
        let finalURL = try #require(URL(string: "https://download.example.com/page"))
        let htmlData = Data("<html><img src=\"image.jpg\"></html>".utf8)
        let response = try #require(HTTPURLResponse(
            url: finalURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html; charset=utf-8"]
        ))
        let provider = RecordingNetworkProvider(data: htmlData, response: response)
        let repository = DefaultQRCodeDumpRepository(networkProvider: provider)

        let document = try await repository.fetchHTMLDocument(from: sourceURL)

        #expect(document.sourceURL == sourceURL)
        #expect(document.finalURL == finalURL)
        #expect(document.htmlData == htmlData)
        #expect(await provider.requestedPaths.first == "")
    }

    @Test("UTF-8이 아닌 HTML은 UTF-8로 변환한다")
    func fetchHTMLDocument_transcodesToUTF8() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let latin1Data = Data([0x63, 0x61, 0x66, 0xE9])
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html; charset=iso-8859-1"]
        ))
        let provider = RecordingNetworkProvider(data: latin1Data, response: response)
        let repository = DefaultQRCodeDumpRepository(networkProvider: provider)

        let document = try await repository.fetchHTMLDocument(from: url)

        #expect(String(data: document.htmlData, encoding: .utf8) == "café")
    }

    @Test("만료 페이지의 오류 상태 HTML도 dump 대상으로 보존한다")
    func fetchHTMLDocument_preservesErrorStatusHTML() async throws {
        let url = try #require(URL(string: "https://example.com/expired"))
        let htmlData = Data("<html>expired</html>".utf8)
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 410,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html; charset=utf-8"]
        ))
        let provider = RecordingNetworkProvider(data: htmlData, response: response)
        let repository = DefaultQRCodeDumpRepository(networkProvider: provider)

        let document = try await repository.fetchHTMLDocument(from: url)

        #expect(document.htmlData == htmlData)
    }

    @Test("1MiB를 넘는 HTML에도 고정 용량 상한을 적용하지 않는다")
    func fetchHTMLDocument_doesNotApplyFixedSizeLimit() async throws {
        let url = try #require(URL(string: "https://example.com/large"))
        let htmlData = Data(repeating: 0x61, count: 2 * 1_024 * 1_024)
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html; charset=utf-8"]
        ))
        let provider = RecordingNetworkProvider(data: htmlData, response: response)
        let repository = DefaultQRCodeDumpRepository(networkProvider: provider)

        let document = try await repository.fetchHTMLDocument(from: url)

        #expect(document.htmlData.count == htmlData.count)
        #expect(document.uploadData.suffix(htmlData.count) == htmlData)
    }

    @Test("ticket 발급과 S3 업로드를 NetworkProvider로 수행한다")
    func issueTicketAndUpload_useNetworkProvider() async throws {
        let provider = RecordingNetworkProvider()
        let repository = DefaultQRCodeDumpRepository(networkProvider: provider)

        let ticket = try await repository.issueUploadTicket()
        try await repository.upload(Data("<html></html>".utf8), with: ticket)

        #expect(ticket.method == "PUT")
        #expect(await provider.requestedPaths == ["media/qr-dumps/upload", ""])
        let uploadRequest = try #require(await provider.lastVoidRequest)
        #expect(uploadRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(uploadRequest.value(forHTTPHeaderField: "Content-Type") == "text/html; charset=utf-8")
    }
}

private actor RecordingNetworkProvider: NetworkProvider {
    private let dataResponse: (Data, HTTPURLResponse)?
    private(set) var requestedPaths: [String] = []
    private(set) var lastVoidRequest: URLRequest?

    init() {
        dataResponse = nil
    }

    init(data: Data, response: HTTPURLResponse) {
        dataResponse = (data, response)
    }

    func request(endpoint: Endpoint) async throws -> (data: Data, response: HTTPURLResponse) {
        requestedPaths.append(endpoint.path)
        guard let dataResponse else { throw TestError.missingDataResponse }
        return dataResponse
    }

    func requestVoid(endpoint: Endpoint) async throws {
        requestedPaths.append(endpoint.path)
        lastVoidRequest = try endpoint.asURLRequest()
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        requestedPaths.append(endpoint.path)
        return BaseResponseDTO(status: "D-0", message: "OK", data: nil)
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        requestedPaths.append(endpoint.path)
        let data = Data(Self.ticketResponse.utf8)
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: data)
    }

    private static let ticketResponse = """
    {
      "resultCode": "D-0",
      "message": "OK",
      "data": {
        "method": "PUT",
        "expiresIn": "2026-10-28T15:00:00Z",
        "uploadTicket": "https://example.com/qr-dump.html?X-Amz-Signature=signature",
        "contentType": "text/html; charset=utf-8"
      }
    }
    """
}

private enum TestError: Error {
    case missingDataResponse
}
