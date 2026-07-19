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
    var supportedHosts: [String] { ["haru4.mx2.co.kr", "haru3.mx2.co.kr", "haru2.mx2.co.kr", "haru1.mx2.co.kr", "haru.mx2.co.kr"] }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
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
            let (data, response) = try await session.data(for: URLRequest(url: imageURL), delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                Logger.network.warning("이미지 다운로드 실패 (상태코드: \(httpResponse.statusCode)). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
            }
            
            return ParsedQRResult(brand: .harufilm, originalImage: data)
            
        } catch {
            Logger.network.warning("이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
}
