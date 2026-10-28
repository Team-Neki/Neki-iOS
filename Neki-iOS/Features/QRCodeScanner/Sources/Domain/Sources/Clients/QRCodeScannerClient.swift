//
//  QRCodeScannerClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/16/26.
//

import Foundation
import AVFoundation
import ComposableArchitecture
import os

struct QRScannerClient {
    var checkAuthorizationStatus: @Sendable () -> AVAuthorizationStatus
    var requestAccess: @Sendable () async -> Bool
    var parse: @Sendable (_ qrCodeString: String, User) async throws -> ParsedQRResult
    var processImage: @Sendable (_ data: Data) async throws -> [Int]
}

extension QRScannerClient: DependencyKey {
    static let liveValue: Self = {
        @Dependency(\.qrCodeScanRepository) var qrCodeScanRepository
        @Dependency(\.qrCodeDumpRepository) var qrCodeDumpRepository
        @Dependency(\.imageUploadRepository) var imageUploadRepository
        return .live(
            qrCodeScanRepository: qrCodeScanRepository,
            qrCodeDumpRepository: qrCodeDumpRepository,
            imageUploadRepository: imageUploadRepository
        )
    }()
}

extension QRScannerClient {
    static func live(
        qrCodeScanRepository: any QRCodeScanRepository,
        qrCodeDumpRepository: any QRCodeDumpRepository,
        imageUploadRepository: any ImageUploadRepository
    ) -> Self {
        let dumpSession = QRCodeDumpSession()

        return Self {
            AVCaptureDevice.authorizationStatus(for: .video)
        } requestAccess: {
            await AVCaptureDevice.requestAccess(for: .video)
        } parse: { qrCodeString, user in
            guard let qrCodeURL = URL(string: qrCodeString) else { throw QRParseError.invalidURL }
            do {
                return try await qrCodeScanRepository.parse(qrCodeURL)
            } catch let error as QRParseError {
                guard case .unsupportedBrand = error,
                      await dumpSession.reserve(qrCodeURL)
                else { throw error }

                Task(priority: .utility) {
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await Self.notifyUnsupportedBrand(
                                url: qrCodeURL,
                                user: user,
                                repository: qrCodeScanRepository
                            )
                        }
                        group.addTask {
                            await dumpSession.acquireUploadSlot()
                            await Self.uploadDump(sourceURL: qrCodeURL, repository: qrCodeDumpRepository)
                            await dumpSession.releaseUploadSlot()
                        }
                    }
                }
                throw error
            }
        } processImage: { data in
            let processed = await ImageDownsamplingProcessor.process(data: data)
            guard let imageData = processed?.data else { throw QRParseError.parsingFailed }
            let imageForUpload = ImageUploadEntity(data: imageData, format: .jpeg)
            return try await imageUploadRepository.upload(items: [imageForUpload], mediaType: .photoBooth)
        }
    }
}

private extension QRScannerClient {
    static func notifyUnsupportedBrand(
        url: URL,
        user: User,
        repository: any QRCodeScanRepository
    ) async {
        do {
            try await repository.notifyUnsupportedBrand(url: url, user: user)
        } catch {
            Logger.network.error("미지원 브랜드 디스코드 웹훅 발송 실패: \(error)")
        }
    }

    static func uploadDump(sourceURL: URL, repository: any QRCodeDumpRepository) async {
        let document: QRCodeDumpDocument
        do {
            document = try await repository.fetchHTMLDocument(from: sourceURL)
        } catch {
            Self.logDumpFailure(error, stage: "download", sourceURL: sourceURL)
            return
        }

        let uploadData = document.uploadData
        let ticket: QRCodeDumpUploadTicket
        do {
            ticket = try await repository.issueUploadTicket()
        } catch {
            Self.logDumpFailure(error, stage: "ticket", sourceURL: sourceURL)
            return
        }

        do {
            try await repository.upload(uploadData, with: ticket)
            Logger.network.info("QR HTML dump 업로드 성공: host=\(sourceURL.host() ?? "unknown"), bytes=\(uploadData.count)")
        } catch {
            Self.logDumpFailure(error, stage: "upload", sourceURL: sourceURL)
        }
    }

    static func logDumpFailure(_ error: Error, stage: String, sourceURL: URL) {
        if error is CancellationError {
            Logger.network.notice("QR HTML dump 작업 취소: stage=\(stage)")
        } else {
            Logger.network.error("QR HTML dump 실패: stage=\(stage), host=\(sourceURL.host() ?? "unknown"), errorType=\(String(reflecting: type(of: error)))")
        }
    }
}

private actor QRCodeDumpSession {
    private var reservedURLs: Set<URL> = []
    private var isUploadSlotOccupied = false
    private var uploadSlotWaiters: [CheckedContinuation<Void, Never>] = []

    func reserve(_ url: URL) -> Bool {
        reservedURLs.insert(url).inserted
    }

    func acquireUploadSlot() async {
        guard isUploadSlotOccupied else {
            isUploadSlotOccupied = true
            return
        }

        await withCheckedContinuation { continuation in
            uploadSlotWaiters.append(continuation)
        }
    }

    func releaseUploadSlot() {
        guard uploadSlotWaiters.isEmpty else {
            uploadSlotWaiters.removeFirst().resume()
            return
        }
        isUploadSlotOccupied = false
    }
}

extension DependencyValues {
    var qrScannerClient: QRScannerClient {
        get { self[QRScannerClient.self] }
        set { self[QRScannerClient.self] = newValue }
    }
}
