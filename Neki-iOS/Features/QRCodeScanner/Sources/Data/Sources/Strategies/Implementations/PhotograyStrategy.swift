//
//  PhotograyStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/11/26.
//

import Foundation

struct PhotograyStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .htmlCrawling }
    
    func canHandle(host: String) -> Bool { PhotoBoothBrand.photogray.hostKeywords.contains(host) }
    
    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        var request = URLRequest(url: url)
        
        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            guard let urlError = error as? URLError else { throw .parsingFailed }
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw .networkError(.networkFail)
            default:
                throw .networkError(.unknownError(urlError))
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              let finalURL = httpResponse.url,
              let components = URLComponents(url: finalURL, resolvingAgainstBaseURL: true),
              let idValue = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let data = Data(base64Encoded: idValue),
              let decodedString = String(data: data, encoding: .utf8)
        else { throw .parsingFailed }
        
        var dummyComponents = URLComponents()
        dummyComponents.query = decodedString
        
        guard let sessionID = dummyComponents.queryItems?.first(where: { $0.name == "sessionId" })?.value else { throw .parsingFailed }
        
        let imageURLString = "https://pg-qr-resource.aprd.io/\(sessionID)/image.jpg"
        guard let imageURL = URL(string: imageURLString) else { throw .urlConstructionFailed }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            return ParsedQRResult(brand: .photogray, originalImage: data)
        } catch {
            throw .imageDownloadFailed
        }
    }
}
