//
//  DefaultQRCodeScanRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation
import Dependencies

struct DefaultQRCodeScanRepository: QRCodeScanRepository {
    private let strategies: [QRCodeParsingStrategy] = [
        HaruFilmStrategy(),
        PhotograyStrategy(),
        PhotoSignatureStrategy(),
        Life4CutStrategy(),
        PhotoismStrategy()
    ]
    
    @Dependency(\.networkProvider) private var networkProvider
    
    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
        guard let host = url.host() else { throw .invalidURL }
        
        for strategy in strategies {
            guard strategy.canHandle(host: host) else { continue }
            return try await strategy.parse(url, networkProvider: networkProvider)
        }
        
        throw .unsupportedBrand
    }
}
