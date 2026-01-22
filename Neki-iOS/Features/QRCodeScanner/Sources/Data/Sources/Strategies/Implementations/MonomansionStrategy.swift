//
//  MonomansionStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation

// TODO: 모노맨션 브랜드는 나중에 출시
//struct MonoMansionStrategy: QRCodeParsingStrategy {
//    var strategyType: ParsingStrategyType { .htmlCrawling }
//    
//    func canHandle(host: String) -> Bool {
//        PhotoBoothBrand.monoMansion.hostKeywords.contains(host)
//    }
//    
//    func parse(_ url: URL, networkProvider: NetworkProvider) async throws(QRParseError) -> ParsedQRResult {
//        // 1. HTML 데이터 요청
//        var request = URLRequest(url: url)
//        // 봇 차단 방지용 헤더
//        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
//        
//        let data: Data
//        do {
//            // 현재 단계에서는 URLSession 직접 사용
//            (data, _) = try await URLSession.shared.data(for: request)
//        } catch {
//            guard let urlError = error as? URLError else { throw .parsingFailed }
//            switch urlError.code {
//            case .notConnectedToInternet, .networkConnectionLost:
//                throw .networkError(.networkFail)
//            default:
//                throw .networkError(.unknownError(urlError))
//            }
//        }
//        
//        // 2. HTML 문자열 변환
//        guard let htmlString = String(data: data, encoding: .utf8) else {
//            throw .parsingFailed
//        }
//        
//        // 3. 정규식을 통한 이미지 URL 추출
//        // 제공된 정규식: href\s*=\s*["'](https://[^"']*ncloudstorage\.com[^"']+\.jpg)["']
//        // 그룹 1번(괄호 안의 내용)이 실제 URL입니다.
//        let pattern = "href\\s*=\\s*[\"'](https://[^\"']*ncloudstorage\\.com[^\"']+\\.jpg)[\"']"
//        
//        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
//              let match = regex.firstMatch(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.utf16.count)),
//              let range = Range(match.range(at: 1), in: htmlString) else {
//            throw .parsingFailed
//        }
//        
//        let imageURLString = String(htmlString[range])
//        
//        guard let imageURL = URL(string: imageURLString) else {
//            throw .urlConstructionFailed
//        }
//        
//        return ParsedQRResult(brand: .monoMansion, originalImageURL: imageURL)
//    }
//}
