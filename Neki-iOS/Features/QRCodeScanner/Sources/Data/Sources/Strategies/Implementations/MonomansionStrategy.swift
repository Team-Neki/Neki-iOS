//
//  MonomansionStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation
import os

struct MonomansionStrategy: QRCodeParsingStrategy {
    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .htmlCrawling }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(normalizedHost: String) -> Bool { QRCodeBrand.monoMansion.hostKeywords.contains { normalizedHost.contains($0) } }

    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("모노맨션 파싱 시도: \(qrCodeURL.absoluteString)")
        
        let request = URLRequest(url: qrCodeURL)
        let htmlData: Data
        
        do {
            (htmlData, _) = try await session.data(for: request, delegate: nil)
        } catch {
            Logger.network.error("모노맨션 HTML 요청 실패: \(error.localizedDescription)")
            if let urlError = error as? URLError,
               [.notConnectedToInternet, .networkConnectionLost].contains(urlError.code) {
                throw .networkError(.networkFail)
            }
            throw .fallbackToWebView(qrCodeURL)
        }
        
        guard let htmlString = String(data: htmlData, encoding: .utf8) else {
            Logger.domain.warning("모노맨션 HTML 문자열 변환 실패.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        let pattern = #"href\s*=\s*["'](https://[^"']*ncloudstorage\.com[^"']+\.jpg(?:\?[^"']*)?)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: htmlString,
                options: [],
                range: NSRange(location: 0, length: htmlString.utf16.count)
              ),
              let range = Range(match.range(at: 1), in: htmlString)
        else {
            Logger.domain.warning("모노맨션 이미지 URL 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        let imageSourceURLString = String(htmlString[range])
            .replacingOccurrences(of: "&amp;", with: "&")
        
        guard let imageSourceURL = URL(string: imageSourceURLString) else {
            Logger.domain.error("모노맨션 이미지 URL 생성 실패.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageSourceURL), delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                Logger.network.warning("모노맨션 이미지 다운로드 실패 (상태코드: \(httpResponse.statusCode)). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }
            
            return ParsedQRResult(brand: .monoMansion, originalImage: data)
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("모노맨션 이미지 다운로드 실패: \(error.localizedDescription)")
            throw .imageDownloadFailed
        }
    }
}
