//
//  PhotograyStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/11/26.
//

import Foundation
import os

struct PhotograyStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .htmlCrawling }
    
    func canHandle(host: String) -> Bool { QRCodeBrand.photogray.hostKeywords.contains { host.contains($0) } }
    
    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("포토그레이 파싱 시도: \(url.absoluteString)")
        
        let request = URLRequest(url: url)
        
        // 1. 리다이렉트 URL 획득 시도
        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            Logger.network.error("초기 네트워크 접속 실패: \(error.localizedDescription)")
            if let urlError = error as? URLError, [.notConnectedToInternet, .networkConnectionLost].contains(urlError.code) {
                throw .networkError(.networkFail)
            }
            throw .fallbackToWebView(url)
        }
        
        // 2. 파라미터 추출 및 디코딩 로직
        guard let httpResponse = response as? HTTPURLResponse,
              let finalURL = httpResponse.url,
              let components = URLComponents(url: finalURL, resolvingAgainstBaseURL: true),
              let idValue = components.queryItems?.first(where: { $0.name == "id" })?.value
        else {
            Logger.domain.warning("리다이렉트 URL에서 id 파라미터 찾기 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
        
        // Base64 디코딩 실패 시 폴백
        guard let data = Data(base64Encoded: idValue),
              let decodedString = String(data: data, encoding: .utf8) else {
            Logger.data.error("Base64 디코딩 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
        
        // 3. 디코딩된 문자열에서 sessionId 추출
        var dummyComponents = URLComponents()
        dummyComponents.query = decodedString
        
        guard let sessionID = dummyComponents.queryItems?.first(where: { $0.name == "sessionId" })?.value else {
            Logger.domain.warning("sessionId 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
        
        // 4. 최종 이미지 URL 구성
        let imageURLString = "https://pg-qr-resource.aprd.io/\(sessionID)/image.jpg"
        guard let imageURL = URL(string: imageURLString) else {
            Logger.domain.error("최종 이미지 URL 구성 불가.")
            throw .fallbackToWebView(url)
        }
        
        // 5. 다운로드
        do {
            let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
            
            if let httpResponse = imageResponse as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) == false {
                Logger.network.warning("이미지 리소스 접근 실패(만료됨). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
            }
            
            return ParsedQRResult(brand: .photogray, originalImage: imageData)
        } catch {
            Logger.domain.notice("이미지 다운로드 중 에러 발생. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
    }
}
