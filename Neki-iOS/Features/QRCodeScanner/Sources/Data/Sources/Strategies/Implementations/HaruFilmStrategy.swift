//
//  HaruFilmStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation

struct HaruFilmStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .native }
    
    func canHandle(host: String) -> Bool { PhotoBoothBrand.harufilm.hostKeywords.contains(host) }
    
    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        guard let host = url.host() else { throw .invalidURL }
        let path = url.path()
        let id = path.trimmingCharacters(in: ["/", "@"])
        
        guard id.isEmpty == false else { throw .parsingFailed }
        guard let imageURL = URL(string: "http://\(host)/download/album/\(id)/output/output.jpg") else { throw .urlConstructionFailed }
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            return ParsedQRResult(brand: .harufilm, originalImage: data)
        } catch {
            throw .imageDownloadFailed
        }
    }
}
