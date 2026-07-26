//
//  PhotoSignatureCodeStrategy.swift
//  Neki-iOS
//
//  Created by Codex on 7/26/26.
//

import Foundation
import os

struct PhotoSignatureCodeStrategy: QRCodeParsingStrategy {
    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .native }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(host: String) -> Bool {
        QRCodeBrand.photosignatureCode.hostKeywords.contains { host.lowercased().contains($0.lowercased()) }
    }

    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("포토시그니처 CODE 파싱 시도: \(url.absoluteString)")

        guard let sessionID = sessionID(from: url) else {
            Logger.domain.warning("포토시그니처 CODE URL에서 sessionID 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }

        guard let imageURL = URL(
            string: "https://photosignature-asset-cdn.photosignature.workers.dev/sessions/\(sessionID)/final.jpg"
        ) else {
            Logger.domain.error("포토시그니처 CODE 이미지 URL 생성 실패.")
            throw .fallbackToWebView(url)
        }

        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageURL), delegate: nil)

            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                Logger.domain.notice("포토시그니처 CODE 이미지 다운로드 에러. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
            }

            return ParsedQRResult(brand: .photosignatureCode, originalImage: data)
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("포토시그니처 CODE 이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
}

private extension PhotoSignatureCodeStrategy {
    func sessionID(from url: URL) -> String? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard pathComponents.count == 2,
              pathComponents[0].lowercased() == "v"
        else { return nil }

        return pathComponents[1]
    }
}
