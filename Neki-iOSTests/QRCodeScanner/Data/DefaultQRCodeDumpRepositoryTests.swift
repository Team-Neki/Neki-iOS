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
    @Test("HTML을 UTF-8 완성 파일로 구성해 업로드하고 정리한다")
    func prepareAndUpload_writesCompleteDocumentAndCleansFile() async throws {
        let sourceURL = try #require(URL(string: "https://example.com/qr"))
        let finalURL = try #require(URL(string: "https://download.example.com/page"))
        let htmlData = Data("<!DOCTYPE html><html></html>".utf8)
        let response = try makeResponse(
            url: finalURL,
            statusCode: 410,
            contentType: "text/html; charset=utf-8"
        )
        let provider = RecordingNetworkProvider(data: htmlData, response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

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
        #expect(await provider.requestedPaths == ["", "media/qr-dumps/upload", ""])
        #expect(try dumpFiles(in: directoryURL).isEmpty)
    }

    @Test("비 UTF-8 HTML을 bounded 변환하여 UTF-8로 업로드한다")
    func prepareHTMLDocument_transcodesToUTF8() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let latin1Data = Data([0x63, 0x61, 0x66, 0xE9])
        let response = try makeResponse(url: url, contentType: "text/html; charset=iso-8859-1")
        let provider = RecordingNetworkProvider(data: latin1Data, response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        let document = try await repository.prepareHTMLDocument(from: url)
        let ticket = try await repository.issueUploadTicket()
        try await repository.upload(document, with: ticket)

        let uploadedData = try #require(await provider.uploadedData)
        #expect(String(data: uploadedData, encoding: .utf8) == """
        <!-- source: https://example.com/qr -->
        café
        """)
    }

    @Test("멀티바이트 문자가 입력 버퍼 경계에서 나뉘어도 UTF-8로 변환한다")
    func prepareHTMLDocument_transcodesSplitMultibyteCharacter() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        var eucKRData = Data(repeating: 0x61, count: 64 * 1_024 - 1)
        eucKRData.append(contentsOf: [0xB0, 0xA1])
        let response = try makeResponse(url: url, contentType: "text/html; charset=euc-kr")
        let provider = RecordingNetworkProvider(data: eucKRData, response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        let document = try await repository.prepareHTMLDocument(from: url)
        let ticket = try await repository.issueUploadTicket()
        try await repository.upload(document, with: ticket)

        let uploadedData = try #require(await provider.uploadedData)
        let uploadedHTML = try #require(String(data: uploadedData, encoding: .utf8))
        #expect(uploadedHTML.hasSuffix("가"))
    }

    @Test("BOM으로 판별한 UTF-16 byte order를 다음 입력 버퍼에도 유지한다")
    func prepareHTMLDocument_preservesUTF16ByteOrderAcrossBuffers() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let body = String(repeating: "가", count: 40_000)
        var utf16Data = Data([0xFE, 0xFF])
        utf16Data.append(try #require(body.data(using: .utf16BigEndian)))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-16")
        let provider = RecordingNetworkProvider(data: utf16Data, response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        let document = try await repository.prepareHTMLDocument(from: url)
        let ticket = try await repository.issueUploadTicket()
        try await repository.upload(document, with: ticket)

        let uploadedData = try #require(await provider.uploadedData)
        let uploadedHTML = try #require(String(data: uploadedData, encoding: .utf8))
        #expect(uploadedHTML.hasSuffix(body))
    }

    @Test("ticket 발급 전에 폐기하면 완성된 임시 파일을 제거한다")
    func discard_removesPreparedDocument() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let provider = RecordingNetworkProvider(data: Data("<html></html>".utf8), response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        let document = try await repository.prepareHTMLDocument(from: url)
        await repository.discard(document)

        #expect(try dumpFiles(in: directoryURL).isEmpty)
    }

    @Test("파일 업로드가 실패해도 완성된 임시 파일을 제거한다")
    func uploadFailure_removesPreparedDocument() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let provider = RecordingNetworkProvider(
            data: Data("<html></html>".utf8),
            response: response,
            shouldFailUpload: true
        )
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        let document = try await repository.prepareHTMLDocument(from: url)
        let ticket = try await repository.issueUploadTicket()
        await #expect(throws: TestError.self) {
            try await repository.upload(document, with: ticket)
        }

        #expect(try dumpFiles(in: directoryURL).isEmpty)
    }

    @Test("첫 준비 작업에서 이전 실행의 잔여 파일을 정리한다")
    func prepareHTMLDocument_removesStaleFiles() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let provider = RecordingNetworkProvider(data: Data("<html></html>".utf8), response: response)
        let directoryURL = temporaryDirectoryURL()
        let dumpDirectoryURL = directoryURL.appendingPathComponent("neki-qr-dumps", isDirectory: true)
        let staleSessionURL = dumpDirectoryURL.appendingPathComponent("previous-session", isDirectory: true)
        try FileManager.default.createDirectory(at: staleSessionURL, withIntermediateDirectories: true)
        let staleFileURL = staleSessionURL.appendingPathComponent("stale.html")
        try Data("stale".utf8).write(to: staleFileURL)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        let document = try await repository.prepareHTMLDocument(from: url)

        #expect(FileManager.default.fileExists(atPath: staleFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: staleSessionURL.path) == false)
        await repository.discard(document)
    }

    @Test("가용 용량에서 원본과 변환 파일 및 안전 여유를 제외한 동적 상한을 적용한다")
    func prepareHTMLDocument_appliesDynamicStorageLimit() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let provider = RecordingNetworkProvider(data: Data("<html></html>".utf8), response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(
            provider: provider,
            temporaryDirectoryURL: directoryURL,
            availableCapacity: { _ in 500 }
        )

        let document = try await repository.prepareHTMLDocument(from: url)

        #expect(await provider.requestedMaximumBodySizes == [100])
        await repository.discard(document)
    }

    @Test("다운로드 상한에 단일 PUT과 UTF-8 최대 확장률을 반영한다")
    func prepareHTMLDocument_appliesSinglePutLimitBeforeDownload() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let provider = RecordingNetworkProvider(data: Data("<html></html>".utf8), response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        let document = try await repository.prepareHTMLDocument(from: url)

        let maximumSourceBodySize = QRCodeDumpUploadEndpoint.maximumBodySize / 3
        #expect(await provider.requestedMaximumBodySizes == [maximumSourceBodySize])
        await repository.discard(document)
    }

    @Test("UTF-8 문서가 단일 PUT 한도를 넘기 전에 변환을 중단한다")
    func documentWriter_rejectsOversizedOutput() throws {
        let sourceURL = try #require(URL(string: "https://example.com/qr"))
        let directoryURL = temporaryDirectoryURL()
        let sourceFileURL = directoryURL.appendingPathComponent("source.html")
        let outputFileURL = directoryURL.appendingPathComponent("output.html")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("body".utf8).write(to: sourceFileURL)
        #expect(FileManager.default.createFile(atPath: outputFileURL.path, contents: nil))
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let commentByteCount = Data("<!-- source: \(sourceURL.absoluteString) -->\n".utf8).count

        #expect(throws: QRCodeDumpError.self) {
            try QRCodeDumpDocumentWriter.write(
                sourceFileURL: sourceFileURL,
                uploadFileURL: outputFileURL,
                sourceURL: sourceURL,
                finalURL: sourceURL,
                encodingName: "utf-8",
                maximumOutputSize: Int64(commentByteCount + 3)
            )
        }
    }

    @Test("가용 용량을 확인할 수 없으면 다운로드를 시작하지 않는다")
    func prepareHTMLDocument_rejectsUnavailableStorageCapacity() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let provider = RecordingNetworkProvider(data: Data("<html></html>".utf8), response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(
            provider: provider,
            temporaryDirectoryURL: directoryURL,
            availableCapacity: { _ in nil }
        )

        await #expect(throws: Error.self) {
            try await repository.prepareHTMLDocument(from: url)
        }

        #expect(await provider.requestedPaths.isEmpty)
        #expect(try dumpFiles(in: directoryURL).isEmpty)
    }

    @Test("64KiB 이상 기록한 다운로드가 실패해도 부분 파일을 모두 제거한다")
    func prepareHTMLDocument_downloadFailureRemovesPartialFiles() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let provider = RecordingNetworkProvider(
            data: Data(repeating: 0x61, count: 64 * 1_024 + 1),
            response: response,
            shouldFailDownloadAfterWrite: true
        )
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = makeRepository(provider: provider, temporaryDirectoryURL: directoryURL)

        await #expect(throws: TestError.self) {
            try await repository.prepareHTMLDocument(from: url)
        }

        #expect(try dumpFiles(in: directoryURL).isEmpty)
    }

    @Test("동일 프로세스의 다른 Repository 인스턴스가 진행 중 파일을 삭제하지 않는다")
    func prepareHTMLDocument_multipleRepositoriesDoNotDeleteCurrentSessionFiles() async throws {
        let url = try #require(URL(string: "https://example.com/qr"))
        let response = try makeResponse(url: url, contentType: "text/html; charset=utf-8")
        let firstProvider = RecordingNetworkProvider(data: Data("first".utf8), response: response)
        let secondProvider = RecordingNetworkProvider(data: Data("second".utf8), response: response)
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let firstRepository = makeRepository(provider: firstProvider, temporaryDirectoryURL: directoryURL)
        let secondRepository = makeRepository(provider: secondProvider, temporaryDirectoryURL: directoryURL)

        let firstDocument = try await firstRepository.prepareHTMLDocument(from: url)
        let secondDocument = try await secondRepository.prepareHTMLDocument(from: url)
        let firstTicket = try await firstRepository.issueUploadTicket()
        try await firstRepository.upload(firstDocument, with: firstTicket)

        #expect(await firstProvider.uploadedData != nil)
        await secondRepository.discard(secondDocument)
        #expect(try dumpFiles(in: directoryURL).isEmpty)
    }
}

private extension DefaultQRCodeDumpRepositoryTests {
    func makeRepository(
        provider: some NetworkProvider & FileTransferProvider,
        temporaryDirectoryURL: URL,
        availableCapacity: @escaping @Sendable (URL) throws -> Int64? = { _ in Int64.max }
    ) -> DefaultQRCodeDumpRepository {
        withDependencies {
            $0.networkProvider = provider
            $0.fileTransferProvider = provider
            $0.qrCodeDumpStorage = QRCodeDumpStorage(temporaryDirectoryURL: temporaryDirectoryURL, availableCapacity: availableCapacity)
        } operation: {
            DefaultQRCodeDumpRepository()
        }
    }

    func temporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func makeResponse(
        url: URL,
        statusCode: Int = 200,
        contentType: String
    ) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": contentType]
        ))
    }

    func dumpFiles(in directoryURL: URL) throws -> [URL] {
        let dumpDirectoryURL = directoryURL.appendingPathComponent("neki-qr-dumps", isDirectory: true)
        guard FileManager.default.fileExists(atPath: dumpDirectoryURL.path),
              let enumerator = FileManager.default.enumerator(at: dumpDirectoryURL, includingPropertiesForKeys: [.isRegularFileKey])
        else { return [] }

        return try enumerator.compactMap { item in
            guard let url = item as? URL,
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            else { return nil }
            return url
        }
    }
}

private actor RecordingNetworkProvider: NetworkProvider, FileTransferProvider {
    private let data: Data
    private let response: HTTPURLResponse
    private let shouldFailUpload: Bool
    private let shouldFailDownloadAfterWrite: Bool
    private(set) var requestedPaths: [String] = []
    private(set) var requestedMaximumBodySizes: [Int64?] = []
    private(set) var uploadedData: Data?

    init(
        data: Data,
        response: HTTPURLResponse,
        shouldFailUpload: Bool = false,
        shouldFailDownloadAfterWrite: Bool = false
    ) {
        self.data = data
        self.response = response
        self.shouldFailUpload = shouldFailUpload
        self.shouldFailDownloadAfterWrite = shouldFailDownloadAfterWrite
    }

    func request(endpoint: any FileDownloadEndpoint, writingTo fileURL: URL) async throws -> HTTPURLResponse {
        requestedPaths.append(endpoint.path)
        requestedMaximumBodySizes.append(endpoint.responseConstraint.maximumBodySize)
        try data.write(to: fileURL)
        guard shouldFailDownloadAfterWrite == false else { throw TestError.downloadFailed }
        return response
    }

    func requestVoid(endpoint: Endpoint) async throws {
        requestedPaths.append(endpoint.path)
    }

    func requestVoid(endpoint: any FileUploadEndpoint, uploading fileURL: URL) async throws {
        requestedPaths.append(endpoint.path)
        guard shouldFailUpload == false else { throw TestError.uploadFailed }
        uploadedData = try Data(contentsOf: fileURL)
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        requestedPaths.append(endpoint.path)
        return BaseResponseDTO(status: "D-0", message: "OK", data: nil)
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        requestedPaths.append(endpoint.path)
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(Self.ticketResponse.utf8))
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
    case downloadFailed
    case uploadFailed
}
