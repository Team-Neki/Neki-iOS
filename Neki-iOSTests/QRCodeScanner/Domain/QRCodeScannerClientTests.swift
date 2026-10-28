//
//  QRCodeScannerClientTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 10/28/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct QRCodeScannerClientTests {
    @Test("미지원 브랜드는 실패를 즉시 반환하고 dump를 background에서 시작한다")
    func parseUnsupportedBrand_returnsBeforeBackgroundDumpCompletes() async throws {
        let scanRepository = UnsupportedScanRepository()
        let dumpRepository = RecordingDumpRepository()
        let client = makeClient(scanRepository: scanRepository, dumpRepository: dumpRepository)

        do {
            _ = try await client.parse("https://unsupported.example.com/qr", .dummy)
            Issue.record("미지원 브랜드 오류가 필요합니다.")
        } catch let error as QRParseError {
            guard case .unsupportedBrand = error else {
                Issue.record("예상하지 못한 오류: \(error)")
                return
            }
        }

        await dumpRepository.waitForUploadCount(1)
        await scanRepository.waitForNotification()
        #expect(await dumpRepository.uploadCount == 1)
        #expect(await scanRepository.notificationCount == 1)
    }

    @Test("같은 URL은 순차·동시 호출에서 세션당 한 번만 dump한다")
    func parseUnsupportedBrand_deduplicatesSameURL() async {
        let scanRepository = UnsupportedScanRepository()
        let dumpRepository = RecordingDumpRepository()
        let client = makeClient(scanRepository: scanRepository, dumpRepository: dumpRepository)
        let url = "https://unsupported.example.com/qr"

        async let first: Void = ignoreError { _ = try await client.parse(url, .dummy) }
        async let second: Void = ignoreError { _ = try await client.parse(url, .dummy) }
        _ = await (first, second)
        await ignoreError { _ = try await client.parse(url, .dummy) }

        await dumpRepository.waitForUploadCount(1)
        #expect(await dumpRepository.uploadCount == 1)
        #expect(await dumpRepository.fetchCount == 1)
    }

    @Test("서로 다른 URL의 dump도 한 번에 하나만 실행한다")
    func parseUnsupportedBrand_serializesDifferentURLs() async {
        let dumpRepository = RecordingDumpRepository(operationDelay: .milliseconds(50))
        let client = makeClient(scanRepository: UnsupportedScanRepository(), dumpRepository: dumpRepository)

        async let first: Void = ignoreError {
            _ = try await client.parse("https://unsupported.example.com/first", .dummy)
        }
        async let second: Void = ignoreError {
            _ = try await client.parse("https://unsupported.example.com/second", .dummy)
        }
        _ = await (first, second)

        await dumpRepository.waitForUploadCount(2)
        #expect(await dumpRepository.uploadCount == 2)
        #expect(await dumpRepository.maximumConcurrentOperationCount == 1)
    }

    @Test("지원 브랜드 파싱 성공은 dump 의존성을 호출하지 않는다")
    func parseSupportedBrand_doesNotStartDump() async throws {
        let dumpRepository = RecordingDumpRepository()
        let client = makeClient(scanRepository: SupportedScanRepository(), dumpRepository: dumpRepository)

        _ = try await client.parse("https://supported.example.com/qr", .dummy)
        await Task.yield()

        #expect(await dumpRepository.fetchCount == 0)
        #expect(await dumpRepository.ticketCount == 0)
        #expect(await dumpRepository.uploadCount == 0)
    }
}

private extension QRCodeScannerClientTests {
    func makeClient(scanRepository: any QRCodeScanRepository, dumpRepository: any QRCodeDumpRepository) -> QRScannerClient {
        .live(
            qrCodeScanRepository: scanRepository,
            qrCodeDumpRepository: dumpRepository,
            imageUploadRepository: ImageUploadRepositoryStub()
        )
    }

    func ignoreError(_ operation: () async throws -> Void) async {
        do { try await operation() } catch {}
    }
}

private actor UnsupportedScanRepository: QRCodeScanRepository {
    private(set) var notificationCount = 0
    private var notificationWaiters: [CheckedContinuation<Void, Never>] = []

    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        throw .unsupportedBrand
    }

    func notifyUnsupportedBrand(url: URL, user: User) async throws {
        notificationCount += 1
        notificationWaiters.forEach { $0.resume() }
        notificationWaiters.removeAll()
    }

    func waitForNotification() async {
        guard notificationCount == 0 else { return }
        await withCheckedContinuation { continuation in
            notificationWaiters.append(continuation)
        }
    }
}

private struct SupportedScanRepository: QRCodeScanRepository {
    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        ParsedQRResult(brand: .monoMansion, originalImage: Data([0x01]))
    }

    func notifyUnsupportedBrand(url: URL, user: User) async throws {}
}

private actor RecordingDumpRepository: QRCodeDumpRepository {
    private let operationDelay: Duration?
    private(set) var fetchCount = 0
    private(set) var ticketCount = 0
    private(set) var uploadCount = 0
    private(set) var maximumConcurrentOperationCount = 0
    private var concurrentOperationCount = 0
    private var uploadWaiters: [(expectedCount: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(operationDelay: Duration? = nil) {
        self.operationDelay = operationDelay
    }

    func fetchHTMLDocument(from sourceURL: URL) async throws -> QRCodeDumpDocument {
        concurrentOperationCount += 1
        maximumConcurrentOperationCount = max(maximumConcurrentOperationCount, concurrentOperationCount)
        if let operationDelay {
            try await Task.sleep(for: operationDelay)
        }
        concurrentOperationCount -= 1
        fetchCount += 1
        return QRCodeDumpDocument(
            sourceURL: sourceURL,
            finalURL: sourceURL,
            htmlData: Data("<html></html>".utf8)
        )
    }

    func issueUploadTicket() async throws -> QRCodeDumpUploadTicket {
        ticketCount += 1
        return QRCodeDumpUploadTicket(
            method: "PUT",
            expiresIn: "2026-10-28T15:00:00Z",
            uploadTicket: "https://example.com/upload",
            contentType: "text/html; charset=utf-8"
        )
    }

    func upload(_ data: Data, with ticket: QRCodeDumpUploadTicket) async throws {
        uploadCount += 1
        let satisfiedWaiters = uploadWaiters.filter { $0.expectedCount <= uploadCount }
        uploadWaiters.removeAll { $0.expectedCount <= uploadCount }
        satisfiedWaiters.forEach { $0.continuation.resume() }
    }

    func waitForUploadCount(_ expectedCount: Int) async {
        guard uploadCount < expectedCount else { return }
        await withCheckedContinuation { continuation in
            uploadWaiters.append((expectedCount, continuation))
        }
    }
}

private struct ImageUploadRepositoryStub: ImageUploadRepository {
    func upload(items: [ImageUploadEntity], mediaType: ImageMediaType) async throws -> [Int] { [] }
}
