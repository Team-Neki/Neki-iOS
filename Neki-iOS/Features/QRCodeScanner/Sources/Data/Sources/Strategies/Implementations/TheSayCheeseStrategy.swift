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

    func canHandle(normalizedHost: String) -> Bool {
        QRCodeBrand.theSayCheese.hostKeywords.contains(normalizedHost)
    }

    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("더세이치즈 파싱 시도: \(qrCodeURL.absoluteString)")

        guard let imageSourceURL = imageSourceURL(from: qrCodeURL) else {
            Logger.domain.warning("더세이치즈 이미지 URL 생성 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }

        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageSourceURL), delegate: nil)

            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                Logger.network.warning("더세이치즈 이미지 다운로드 실패 (상태코드: \(httpResponse.statusCode)). 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
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
    static let asciiDigitRange = UInt8(ascii: "0")...UInt8(ascii: "9")
    static let identifierAllowedCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "-_")
    )

    func imageSourceURL(from qrCodeURL: URL) -> URL? {
        guard let queryItems = URLComponents(
            url: qrCodeURL,
            resolvingAgainstBaseURL: false
        )?.queryItems,
              let identifier = queryItems.first(where: { $0.name == "idx" })?.value,
              identifier.isEmpty == false,
              identifier.unicodeScalars.allSatisfy({ Self.identifierAllowedCharacters.contains($0) }),
              let date = queryItems.first(where: { $0.name == "ymd" })?.value,
              date.utf8.count == 6,
              date.utf8.allSatisfy(Self.asciiDigitRange.contains),
              let baseURL = URL(string: "http://thesaycheese.co.kr")
        else { return nil }

        return baseURL
            .appending(path: "image")
            .appending(path: date)
            .appending(path: identifier)
            .appendingPathExtension("jpg")
    }
}
