//
//  Life4CutStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation

struct Life4CutStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .htmlCrawling }
    
    func canHandle(host: String) -> Bool { PhotoBoothBrand.life4cut.hostKeywords.contains(host) }
    
    func parse(_ url: URL, networkProvider: any NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        var request = URLRequest(url: url)
        
        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .networkError(.networkFail)
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              let finalURL = httpResponse.url,
              let components = URLComponents(url: finalURL, resolvingAgainstBaseURL: true),
              let bucket = components.queryItems?.first(where: { $0.name == "bucket" })?.value,
              let region = components.queryItems?.first(where: { $0.name == "region" })?.value,
              let folderPath = components.queryItems?.first(where: { $0.name == "folderPath" })?.value
        else { throw .parsingFailed }
        
        let imageURLString = "https://\(bucket).s3.\(region).amazonaws.com\(folderPath)/image.jpg"
        guard let imageURL = URL(string: imageURLString) else { throw .urlConstructionFailed }
        
        var imageRequest = URLRequest(url: imageURL)
        imageRequest.setValue("https://download.life4cut.net", forHTTPHeaderField: "Referer")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: imageRequest)
            return ParsedQRResult(brand: .life4cut, originalImage: data)
        } catch {
            throw .imageDownloadFailed
        }
    }
}
