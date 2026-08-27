//
//  HaruFilmStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation
import os

struct HaruFilmStrategy: QRCodeParsingStrategy {
    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .native }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(normalizedHost: String) -> Bool { QRCodeBrand.harufilm.hostKeywords.contains { normalizedHost.contains($0) } }

    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("하루필름 파싱 시도: \(qrCodeURL.absoluteString)")
        
        guard let host = qrCodeURL.host() else {
            Logger.domain.error("유효하지 않은 호스트")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        let path = qrCodeURL.path()
        let id = path.trimmingCharacters(in: ["/", "@"])
        
        guard id.isEmpty == false else {
            Logger.domain.warning("ID 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        guard let imageSourceURL = URL(string: "http://\(host)/download/album/\(id)/output/output.jpg") else {
            Logger.domain.error("이미지 URL 구성 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageSourceURL), delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                Logger.network.warning("이미지 다운로드 실패 (상태코드: \(httpResponse.statusCode)). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }
            
            return ParsedQRResult(brand: .harufilm, originalImage: data)
            
        } catch {
            Logger.network.warning("이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
}
