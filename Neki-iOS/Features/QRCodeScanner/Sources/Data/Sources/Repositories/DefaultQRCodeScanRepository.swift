//
//  DefaultQRCodeScanRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation
import Dependencies
import ImageIO
import os

struct DefaultQRCodeScanRepository: QRCodeScanRepository {
    private let strategies: [QRCodeParsingStrategy]
    
    @Dependency(\.networkProvider) private var networkProvider

    init(session: URLSessionProtocol = URLSession.shared) {
        strategies = [
            AuraPicStrategy(session: session),
            HaruFilmStrategy(session: session),
            PhotograyStrategy(session: session),
            PhotoSignatureCodeStrategy(session: session),
            PhotoSignatureStrategy(session: session),
            Life4CutStrategy(session: session),
            MonomansionStrategy(session: session),
            TheSayCheeseStrategy(session: session),
            PixPixLinkStrategy(session: session),
            PhotoismStrategy()
        ]
    }
    
    func parse(_ qrCodeURL: URL, user: User) async throws(QRParseError) -> ParsedQRResult {
        guard let host = qrCodeURL.host() else { throw .invalidURL }
        
        for strategy in strategies {
            guard strategy.canHandle(host: host) else { continue }
            let parsedResult = try await strategy.parse(qrCodeURL)
            guard isValidImageData(parsedResult.originalImage) else { throw .fallbackToWebView(qrCodeURL) }
            return parsedResult
        }
        
        Task.detached(priority: .background) {
            do {
                let endpoint = QRCodeScannerEndpoint.notifyUnsupportedBrand(url: qrCodeURL, user: user)
                try await networkProvider.requestVoid(endpoint: endpoint)
            } catch {
                Logger.network.error("미지원 브랜드 디스코드 웹훅 발송 실패: \(error)")
            }
        }
        
        throw .unsupportedBrand
    }
}

private extension DefaultQRCodeScanRepository {
    func isValidImageData(_ data: Data) -> Bool {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return false }
        return CGImageSourceGetStatus(imageSource) == .statusComplete
            && CGImageSourceGetCount(imageSource) > .zero
            && CGImageSourceGetType(imageSource) != nil
    }
}
