//
//  DefaultQRCodeDumpRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 10/28/26.
//

import Dependencies
import Foundation
import Testing
@testable import Neki_iOS

struct DefaultQRCodeDumpRepositoryTests {
    @Test("HTML과 source/final 주석을 하나의 body로 업로드한다")
    func prepareAndUpload_buildsCompleteBody() async throws {
        let sourceURL = try #require(URL(string: "https://example.com/qr"))
        let finalURL = try #require(URL(string: "https://download.example.com/page"))
        let provider = RecordingNetworkProvider(
            data: Data("<!DOCTYPE html><html></html>".utf8),
            response: try makeResponse(url: finalURL, contentType: "text/html; charset=utf-8")
        )
        let repository = makeRepository(provider: provider)

        let document = try await repository.prepareHTMLDocument(from: sourceURL)
        let ticket = try await repository.issueUploadTicket()
        try await repository.upload(document, with: ticket)

        let uploadedData = try #require(await provider.uploadedData)
        let uploadedHTML = try #require(String(data: uploadedData, encoding: .utf8))
        #expect(uploadedHTML == """
        <!-- source: https://example.com/qr -->
        <!-- final: https://download.example.com/page -->
        <!DOCTYPE html><html></html>
        """)
        #expect(document.byteCount == uploadedData.count)
    }

    @Test("비 UTF-8 HTML을 5MiB 범위 안에서 UTF-8로 변환한다")
    func prepareHTMLDocument_transcodesToUTF8() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let provider = RecordingNetworkProvider(
            data: Data([0x63, 0x61, 0x66, 0xE9]),
            response: try makeResponse(url: url, contentType: "text/html; charset=iso-8859-1")
        )
        let repository = makeRepository(provider: provider)

        let document = try await repository.prepareHTMLDocument(from: url)

        #expect(String(data: document.data, encoding: .utf8) == """
        <!-- source: https://example.com/qr -->
        café
        """)
    }

    @Test("source 주석을 포함한 최종 body가 5MiB를 넘으면 거부한다")
    func prepareHTMLDocument_rejectsBodyOverServerLimit() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let provider = RecordingNetworkProvider(
            data: Data(repeating: 0x61, count: 5 * 1_024 * 1_024),
            response: try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        )
        let repository = makeRepository(provider: provider)

        await #expect(throws: QRCodeDumpError.self) {
            try await repository.prepareHTMLDocument(from: url)
        }
    }

    @Test("비 UTF-8 원문은 변환된 실제 body 크기로 판정한다")
    func prepareHTMLDocument_validatesTranscodedBodySize() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let provider = RecordingNetworkProvider(
            data: Data(repeating: 0x61, count: 2 * 1_024 * 1_024),
            response: try makeResponse(url: url, contentType: "text/html; charset=iso-8859-1")
        )
        let repository = makeRepository(provider: provider)

        let document = try await repository.prepareHTMLDocument(from: url)

        #expect(document.byteCount < 5 * 1_024 * 1_024)
    }
}

private extension DefaultQRCodeDumpRepositoryTests {
    func makeRepository(provider: some NetworkProvider) -> DefaultQRCodeDumpRepository {
        withDependencies {
            $0.networkProvider = provider
        } operation: {
            DefaultQRCodeDumpRepository()
        }
    }

    func makeResponse(url: URL, contentType: String) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": contentType]
        ))
    }
}

private actor RecordingNetworkProvider: NetworkProvider {
    private let data: Data
    private let response: HTTPURLResponse
    private(set) var uploadedData: Data?

    init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }

    func request(endpoint: Endpoint) async throws -> (data: Data, response: HTTPURLResponse) {
        (data, response)
    }

    func requestVoid(endpoint: Endpoint) async throws {
        uploadedData = try endpoint.asURLRequest().httpBody
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        BaseResponseDTO(status: "D-0", message: "OK", data: nil)
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(Self.ticketResponse.utf8))
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
