//
//  PixPixLinkStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/7/26.
//

import Foundation
import os

struct PixPixLinkStrategy: QRCodeParsingStrategy {
    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .native }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(normalizedHost: String) -> Bool {
        QRCodeBrand.pixPixLink.hostKeywords.contains(normalizedHost)
    }

    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("PixPixLink 파싱 시도: \(qrCodeURL.absoluteString)")

        guard let imageSourceURL = imageSourceURL(from: qrCodeURL) else {
            Logger.domain.warning("PixPixLink 이미지 URL 생성 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }

        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageSourceURL), delegate: nil)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  data.isEmpty == false
            else {
                Logger.network.warning("PixPixLink 이미지 다운로드 실패 또는 만료. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }
            return ParsedQRResult(brand: .pixPixLink, originalImage: data)
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("PixPixLink 이미지 다운로드 실패: \(error.localizedDescription)")
            throw .imageDownloadFailed
        }
    }
}

private extension PixPixLinkStrategy {
    static let parameterAllowedCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "-_")
    )

    func imageSourceURL(from qrCodeURL: URL) -> URL? {
        guard var components = URLComponents(url: qrCodeURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let directory = queryItems.first(where: { $0.name == "d" })?.value,
              directory.isEmpty == false,
              directory.unicodeScalars.allSatisfy({ Self.parameterAllowedCharacters.contains($0) }),
              let identifier = queryItems.first(where: { $0.name == "i" })?.value,
              identifier.isEmpty == false,
              identifier.unicodeScalars.allSatisfy({ Self.parameterAllowedCharacters.contains($0) })
        else { return nil }

        components.scheme = "https"
        components.path = "/t/\(directory)/\(identifier).jpg"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
