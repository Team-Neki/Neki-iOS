//
//  Life4CutStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation
import os

struct Life4CutStrategy: QRCodeParsingStrategy {
    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .htmlCrawling }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(host: String) -> Bool { QRCodeBrand.life4cut.hostKeywords.contains { host.lowercased().contains($0.lowercased()) } }

    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("인생네컷 파싱 시도: \(url.absoluteString)")
        
        let request = URLRequest(url: url)
        
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request, delegate: nil)
        } catch {
            Logger.network.error("초기 연결 실패: \(error.localizedDescription)")
            throw .networkError(.networkFail)
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              let finalURL = httpResponse.url,
              let components = URLComponents(url: finalURL, resolvingAgainstBaseURL: true),
              let bucket = components.queryItems?.first(where: { $0.name == "bucket" })?.value,
              let region = components.queryItems?.first(where: { $0.name == "region" })?.value,
              let folderPath = components.queryItems?.first(where: { $0.name == "folderPath" })?.value
        else {
            Logger.domain.warning("파라미터 추출 실패. 웹뷰 폴백 시도.")
            throw .fallbackToWebView(url)
        }
        
        let imageURLString = "https://\(bucket).s3.\(region).amazonaws.com\(folderPath)/image.jpg"
        guard let imageURL = URL(string: imageURLString) else {
            Logger.domain.error("S3 URL 생성 불가. 웹뷰 폴백 시도.")
            throw .fallbackToWebView(url)
        }
        
        var imageRequest = URLRequest(url: imageURL)
        imageRequest.setValue("https://download.life4cut.net", forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await session.data(for: imageRequest, delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) == false {
                Logger.network.warning("S3 다운로드 실패 (코드: \(httpResponse.statusCode). 다운로드 기간 만료.")
                throw QRParseError.fallbackToWebView(url)
            }
            return ParsedQRResult(brand: .life4cut, originalImage: data)
        } catch {
            Logger.network.warning("이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
}
