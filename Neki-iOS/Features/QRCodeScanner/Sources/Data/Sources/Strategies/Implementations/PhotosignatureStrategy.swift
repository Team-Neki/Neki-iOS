//
//  PhotosignatureStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation

struct PhotoSignatureStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .native }
    
    func canHandle(host: String) -> Bool {
        PhotoBoothBrand.photosignature.hostKeywords.contains(host)
    }
    
    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        let urlString = url.absoluteString
        let cleanString = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
        let imageURLString = cleanString + "/a.jpg"
        
        guard let imageURL = URL(string: imageURLString) else { throw .urlConstructionFailed }
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            return ParsedQRResult(brand: .photosignature, originalImage: data)
        } catch {
            throw .imageDownloadFailed
        }
    }
}
