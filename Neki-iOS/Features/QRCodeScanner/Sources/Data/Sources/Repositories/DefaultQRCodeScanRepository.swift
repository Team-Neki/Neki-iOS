//
//  DefaultQRCodeScanRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation
import Dependencies
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
            PhotoismStrategy()
        ]
    }
    
    func parse(_ url: URL, user: User) async throws(QRParseError) -> ParsedQRResult {
        guard let host = url.host() else { throw .invalidURL }
        
        for strategy in strategies {
            guard strategy.canHandle(host: host) else { continue }
            return try await strategy.parse(url)
        }
        
        Task.detached(priority: .background) {
            do {
                let endpoint = QRCodeScannerEndpoint.notifyUnsupportedBrand(url: url, user: user)
                try await networkProvider.requestVoid(endpoint: endpoint)
            } catch {
                Logger.network.error("미지원 브랜드 디스코드 웹훅 발송 실패: \(error)")
            }
        }
        
        throw .unsupportedBrand
    }
}
