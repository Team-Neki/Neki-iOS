//
//  HaruFilmStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation
import os

struct HaruFilmStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .native }
    
    func canHandle(host: String) -> Bool { QRCodeBrand.harufilm.hostKeywords.contains { host.contains($0) } }
    
    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("하루필름 파싱 시도: \(url.absoluteString)")
        
        guard let host = url.host() else {
            Logger.domain.error("유효하지 않은 호스트")
            throw .fallbackToWebView(url)
        }
        
        let path = url.path()
        let id = path.trimmingCharacters(in: ["/", "@"])
        
        guard id.isEmpty == false else {
            Logger.domain.warning("ID 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
        
        guard let imageURL = URL(string: "http://\(host)/download/album/\(id)/output/output.jpg") else {
            Logger.domain.error("이미지 URL 구성 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: imageURL)
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                Logger.network.warning("이미지 다운로드 실패 (상태코드: \(httpResponse.statusCode)). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
            }
            
            return ParsedQRResult(brand: .harufilm, originalImage: data)
            
        } catch {
            Logger.domain.notice("이미지 다운로드 연결 실패. 웹뷰 폴백 시도.")
            throw .fallbackToWebView(url)
        }
    }
}
