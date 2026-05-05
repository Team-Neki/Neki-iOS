//
//  MonomansionStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation
import os

struct MonomansionStrategy: QRCodeParsingStrategy {
    var strategyType: ParsingStrategyType { .htmlCrawling }
    
    func canHandle(host: String) -> Bool { QRCodeBrand.monoMansion.hostKeywords.contains { host.lowercased().contains($0.lowercased()) } }
    
    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("모노맨션 파싱 시도: \(url.absoluteString)")
        
        let request = URLRequest(url: url)
        let htmlData: Data
        
        do {
            (htmlData, _) = try await URLSession.shared.data(for: request)
        } catch {
            Logger.network.error("모노맨션 HTML 요청 실패: \(error.localizedDescription)")
            if let urlError = error as? URLError,
               [.notConnectedToInternet, .networkConnectionLost].contains(urlError.code) {
                throw .networkError(.networkFail)
            }
            throw .fallbackToWebView(url)
        }
        
        guard let htmlString = String(data: htmlData, encoding: .utf8) else {
            Logger.domain.warning("모노맨션 HTML 문자열 변환 실패.")
            throw .fallbackToWebView(url)
        }
        
        let pattern = #"href\s*=\s*["'](https://[^"']*ncloudstorage\.com[^"']+\.jpg)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: htmlString,
                options: [],
                range: NSRange(location: 0, length: htmlString.utf16.count)
              ),
              let range = Range(match.range(at: 1), in: htmlString)
        else {
            Logger.domain.warning("모노맨션 이미지 URL 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
        
        let imageURLString = String(htmlString[range])
            .replacingOccurrences(of: "&amp;", with: "&")
        
        guard let imageURL = URL(string: imageURLString) else {
            Logger.domain.error("모노맨션 이미지 URL 생성 실패.")
            throw .fallbackToWebView(url)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: imageURL)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                Logger.network.warning("모노맨션 이미지 다운로드 실패 (상태코드: \(httpResponse.statusCode)). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
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
