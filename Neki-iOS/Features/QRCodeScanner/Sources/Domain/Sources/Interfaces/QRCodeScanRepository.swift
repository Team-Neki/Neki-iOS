//
//  QRCodeScanRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation
import Dependencies
import DependenciesMacros

public enum QRParseError: Error {
    case invalidURL
    case unsupportedBrand
    case parsingFailed
    case urlConstructionFailed
    case networkError(NetworkError)
    case imageDownloadFailed
    case fallbackToWebView(URL)
}

public protocol QRCodeScanRepository {
    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult
}

private enum QRCodeScanRepositoryKey: DependencyKey {
    static let liveValue: QRCodeScanRepository = DefaultQRCodeScanRepository()
}

// MARK: - QRCodeScanRepository + Accessor

extension DependencyValues {
    var qrCodeScanRepository: QRCodeScanRepository {
        get { self[QRCodeScanRepositoryKey.self] }
        set { self[QRCodeScanRepositoryKey.self] = newValue }
    }
}
