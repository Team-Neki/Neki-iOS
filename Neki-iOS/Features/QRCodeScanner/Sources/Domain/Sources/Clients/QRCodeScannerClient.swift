//
//  QRCodeScannerClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/16/26.
//

import Foundation
import AVFoundation
import ComposableArchitecture

struct QRScannerClient {
    var checkAuthorizationStatus: @Sendable () -> AVAuthorizationStatus
    var requestAccess: @Sendable () async -> Bool
    var parse: @Sendable (_ urlString: String, User) async throws -> ParsedQRResult
    var processImage: @Sendable (_ data: Data) async throws -> [Int]
}

extension QRScannerClient: DependencyKey {
    static let liveValue: Self = {
        @Dependency(\.qrCodeScanRepository) var qrCodeScanRepository
        @Dependency(\.imageUploadRepository) var imageUploadRepository
        
        return Self {
            AVCaptureDevice.authorizationStatus(for: .video)
        } requestAccess: {
            await AVCaptureDevice.requestAccess(for: .video)
        } parse: { urlString, user in
            guard let url = URL(string: urlString) else { throw QRParseError.invalidURL }
            return try await qrCodeScanRepository.parse(url, user: user)
        } processImage: { data in
            let processed = await ImageDownsamplingProcessor.process(data: data)
            guard let imageData = processed?.data else { throw QRParseError.parsingFailed }
            let imageForUpload = ImageUploadEntity(data: imageData, format: .jpeg)
            return try await imageUploadRepository.upload(items: [imageForUpload], mediaType: .photoBooth)
        }
    }()
}

extension DependencyValues {
    var qrScannerClient: QRScannerClient {
        get { self[QRScannerClient.self] }
        set { self[QRScannerClient.self] = newValue }
    }
}
