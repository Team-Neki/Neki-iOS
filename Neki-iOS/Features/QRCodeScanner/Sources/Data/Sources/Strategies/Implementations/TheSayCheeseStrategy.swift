//
//  TheSayCheeseStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/26/26.
//

import Foundation
import os

struct TheSayCheeseStrategy: QRCodeParsingStrategy {
    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .native }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(host: String) -> Bool {
        QRCodeBrand.theSayCheese.hostKeywords.contains { host.lowercased() == $0.lowercased() }
    }

    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("더세이치즈 파싱 시도: \(url.absoluteString)")

        guard let imageURL = imageURL(from: url) else {
            Logger.domain.warning("더세이치즈 이미지 URL 생성 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }

        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageURL), delegate: nil)

            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                Logger.network.warning("더세이치즈 이미지 다운로드 실패 (상태코드: \(httpResponse.statusCode)). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
            }

            return ParsedQRResult(brand: .theSayCheese, originalImage: data)
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("더세이치즈 이미지 다운로드 실패: \(error.localizedDescription)")
            throw .imageDownloadFailed
        }
    }
}

private extension TheSayCheeseStrategy {
    static let identifierAllowedCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "-_")
    )

    func imageURL(from url: URL) -> URL? {
        guard let queryItems = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems,
              let identifier = queryItems.first(where: { $0.name == "idx" })?.value,
              identifier.isEmpty == false,
              identifier.unicodeScalars.allSatisfy({ Self.identifierAllowedCharacters.contains($0) }),
              let date = queryItems.first(where: { $0.name == "ymd" })?.value,
              date.count == 6,
              date.allSatisfy(\.isNumber),
              let baseURL = URL(string: "http://thesaycheese.co.kr")
        else { return nil }

        return baseURL
            .appending(path: "image")
            .appending(path: date)
            .appending(path: identifier)
            .appendingPathExtension("jpg")
    }
}
