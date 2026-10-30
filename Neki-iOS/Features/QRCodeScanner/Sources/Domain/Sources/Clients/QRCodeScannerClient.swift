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
    static let liveValue = makeLiveValue()

    static func makeLiveValue() -> Self {
        QRScannerClientFactory().makeClient()
    }
}

private struct QRScannerClientFactory {
    @Dependency(\.qrCodeScanRepository) private var qrCodeScanRepository
    @Dependency(\.qrCodeDumpRepository) private var qrCodeDumpRepository
    @Dependency(\.imageUploadRepository) private var imageUploadRepository

    func makeClient() -> QRScannerClient {
        let qrCodeScanRepository = qrCodeScanRepository
        let qrCodeDumpRepository = qrCodeDumpRepository
        let imageUploadRepository = imageUploadRepository
        let dumpSession = QRCodeDumpSession()

        return QRScannerClient {
            AVCaptureDevice.authorizationStatus(for: .video)
        } requestAccess: {
            await AVCaptureDevice.requestAccess(for: .video)
        } parse: { qrCodeString, user in
            guard let qrCodeURL = URL(string: qrCodeString) else { throw QRParseError.invalidURL }
            do {
                return try await qrCodeScanRepository.parse(qrCodeURL)
            } catch let error as QRParseError {
                guard case .unsupportedBrand = error else { throw error }

                Task(priority: .utility) {
                    await QRScannerClient.notifyUnsupportedBrand(
                        url: qrCodeURL,
                        user: user,
                        repository: qrCodeScanRepository
                    )
                }
                guard await dumpSession.reserve(qrCodeURL) else { throw error }
                await dumpSession.enqueue(url: qrCodeURL) {
                    await QRScannerClient.uploadDump(sourceURL: qrCodeURL, repository: qrCodeDumpRepository)
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

    static func uploadDump(sourceURL: URL, repository: any QRCodeDumpRepository) async -> Bool {
        let document: QRCodeDumpDocument
        do {
            document = try await repository.prepareHTMLDocument(from: sourceURL)
        } catch {
            logDumpFailure(error, stage: "download", sourceURL: sourceURL)
            return false
        }

        let ticket: QRCodeDumpUploadTicket
        do {
            ticket = try await repository.issueUploadTicket()
        } catch {
            logDumpFailure(error, stage: "ticket", sourceURL: sourceURL)
            return false
        }

        do {
            try await repository.upload(document, with: ticket)
            Logger.network.info("QR HTML dump 업로드 성공: host=\(sourceURL.host() ?? "unknown"), bytes=\(document.byteCount)")
            return true
        } catch {
            logDumpFailure(error, stage: "upload", sourceURL: sourceURL)
            return false
        }
    }

    static func logDumpFailure(_ error: Error, stage: String, sourceURL: URL) {
        let reason = dumpFailureReason(error)
        let host = sourceURL.host() ?? "unknown"
        Logger.network.error("QR HTML dump 종료: stage=\(stage), host=\(host), reason=\(reason), errorType=\(String(reflecting: type(of: error)))")
    }

    static func dumpFailureReason(_ error: Error) -> String {
        guard (error is CancellationError) == false else { return "cancelled" }
        if let urlError = error as? URLError {
            guard urlError.networkUnavailableReason != .constrained else { return "constrained" }
            switch urlError.code {
            case .dataNotAllowed: return "constrained"
            case .notConnectedToInternet: return "offline"
            case .networkConnectionLost: return "connectionLost"
            case .timedOut: return "timedOut"
            case .cancelled: return "cancelled"
            default: return "urlError_\(urlError.code.rawValue)"
            }
        }
        if case let NetworkError.unknownError(underlyingError) = error {
            return dumpFailureReason(underlyingError)
        }
        if let networkError = error as? NetworkError {
            switch networkError {
            case .responseTooLarge: return "responseTooLarge"
            case .unsupportedResponseContentType: return "unsupportedContentType"
            default: return "networkError"
            }
        }
        return "unexpected"
    }
}

extension DependencyValues {
    var qrScannerClient: QRScannerClient {
        get { self[QRScannerClient.self] }
        set { self[QRScannerClient.self] = newValue }
    }
}
