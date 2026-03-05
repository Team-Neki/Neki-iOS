//
//  PhotosignatureStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation
import os

struct PhotoSignatureStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .native }
    
    func canHandle(host: String) -> Bool { QRCodeBrand.photosignature.hostKeywords.contains { host.contains($0) } }
    
    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("포토시그니처 파싱 시도: \(url.absoluteString)")
        
        let urlString = url.absoluteString
        var imageURLString = String()
        
        if urlString.hasSuffix("index.html") {
            imageURLString = urlString.replacingOccurrences(of: "index.html", with: "a.jpg")
        } else {
            let cleanString = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
            imageURLString = cleanString + "/a.jpg"
        }
        
        guard let imageURL = URL(string: imageURLString) else {
            Logger.domain.error("이미지 URL 생성 실패.")
            throw .fallbackToWebView(url)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: imageURL)
            
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) == false {
                Logger.domain.notice("이미지 다운로드 에러. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
            }
            
            return ParsedQRResult(brand: .photosignature, originalImage: data)
            
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
}
