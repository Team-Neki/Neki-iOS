//
//  QRCodeScannerClientTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 10/28/26.
//

import Dependencies
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

    @Test("실패한 dump URL은 예약을 해제해 재스캔할 수 있다")
    func parseUnsupportedBrand_releasesFailedDumpReservation() async {
        let dumpRepository = RecordingDumpRepository(preparationFailureCount: 1)
        let client = makeClient(scanRepository: UnsupportedScanRepository(), dumpRepository: dumpRepository)
        let url = "https://unsupported.example.com/retry"

        await ignoreError { _ = try await client.parse(url, .dummy) }
        await dumpRepository.waitForFetchCount(1)

        for _ in 0..<100 {
            guard await dumpRepository.fetchCount < 2 else { break }
            await ignoreError { _ = try await client.parse(url, .dummy) }
            await Task.yield()
        }

        await dumpRepository.waitForUploadCount(1)
        #expect(await dumpRepository.fetchCount == 2)
        #expect(await dumpRepository.uploadCount == 1)
    }

}

private extension QRCodeScannerClientTests {
    func makeClient(
        scanRepository: any QRCodeScanRepository,
        dumpRepository: any QRCodeDumpRepository
    ) -> QRScannerClient {
        return withDependencies {
            $0.qrCodeScanRepository = scanRepository
            $0.qrCodeDumpRepository = dumpRepository
            $0.imageUploadRepository = ImageUploadRepositoryStub()
        } operation: {
            QRScannerClient.makeLiveValue()
        }
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
    private var preparationFailureCount: Int
    private(set) var fetchCount = 0
    private(set) var ticketCount = 0
    private(set) var uploadCount = 0
    private(set) var maximumConcurrentOperationCount = 0
    private var concurrentOperationCount = 0
    private var fetchWaiters: [(expectedCount: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var uploadWaiters: [(expectedCount: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(operationDelay: Duration? = nil, preparationFailureCount: Int = 0) {
        self.operationDelay = operationDelay
        self.preparationFailureCount = preparationFailureCount
    }

    func prepareHTMLDocument(from sourceURL: URL) async throws -> QRCodeDumpDocument {
        fetchCount += 1
        let satisfiedFetchWaiters = fetchWaiters.filter { $0.expectedCount <= fetchCount }
        fetchWaiters.removeAll { $0.expectedCount <= fetchCount }
        satisfiedFetchWaiters.forEach { $0.continuation.resume() }
        guard preparationFailureCount == 0 else {
            preparationFailureCount -= 1
            throw TestError.preparationFailed
        }

        concurrentOperationCount += 1
        maximumConcurrentOperationCount = max(maximumConcurrentOperationCount, concurrentOperationCount)
        defer { concurrentOperationCount -= 1 }
        if let operationDelay { try await Task.sleep(for: operationDelay) }
        return QRCodeDumpDocument(data: Data("<html></html>".utf8))
    }

    func issueUploadTicket() async throws -> QRCodeDumpUploadTicket {
        ticketCount += 1
        return QRCodeDumpUploadTicket(
            method: "PUT",
            uploadTicket: "https://example.com/upload",
            contentType: "text/html; charset=utf-8"
        )
    }

    func upload(_ document: QRCodeDumpDocument, with ticket: QRCodeDumpUploadTicket) async throws {
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

    func waitForFetchCount(_ expectedCount: Int) async {
        guard fetchCount < expectedCount else { return }
        await withCheckedContinuation { continuation in
            fetchWaiters.append((expectedCount, continuation))
        }
    }

}

private struct ImageUploadRepositoryStub: ImageUploadRepository {
    func upload(items: [ImageUploadEntity], mediaType: ImageMediaType) async throws -> [Int] { [] }
}

private enum TestError: Error {
    case preparationFailed
}
