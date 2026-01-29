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
    var parse: @Sendable (_ urlString: String) async throws -> ParsedQRResult
    var processImage: @Sendable (_ data: Data) async -> ImageDownsamplingProcessor.ProcessedImage?
}

extension QRScannerClient: DependencyKey {
    static let liveValue: Self = {
        @Dependency(\.qrCodeScanRepository) var qrCodeScanRepository
        
        return Self {
            AVCaptureDevice.authorizationStatus(for: .video)
        } requestAccess: {
            await AVCaptureDevice.requestAccess(for: .video)
        } parse: { urlString in
            guard let url = URL(string: urlString) else { throw QRParseError.invalidURL }
            return try await qrCodeScanRepository.parse(url)
        } processImage: { data in
            await ImageDownsamplingProcessor.process(data: data)
        }
    }()
}

extension DependencyValues {
    var qrScannerClient: QRScannerClient {
        get { self[QRScannerClient.self] }
        set { self[QRScannerClient.self] = newValue }
    }
}
