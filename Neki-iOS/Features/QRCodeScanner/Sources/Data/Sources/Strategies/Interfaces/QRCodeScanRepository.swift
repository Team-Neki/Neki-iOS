//
//  QRCodeScanRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation

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
