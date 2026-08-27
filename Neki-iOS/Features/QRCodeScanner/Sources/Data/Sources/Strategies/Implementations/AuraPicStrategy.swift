//
//  AuraPicStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/19/26.
//

import Foundation
import os

struct AuraPicStrategy: QRCodeParsingStrategy {
    private enum Constants {
        static let host = "pos.aurapic.co.kr"
        static let shootDataPath = "/api/get/shoot-data"
        static let imageBasePath = "/api/data-download"
        static let imageFileName = "image.jpg"
    }

    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .native }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(normalizedHost: String) -> Bool { QRCodeBrand.auraPic.hostKeywords.contains { normalizedHost.contains($0) } }

    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("아우라픽 파싱 시도: \(qrCodeURL.absoluteString)")

        guard let urlCode = URLComponents(url: qrCodeURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "s" })?
            .value,
              urlCode.isEmpty == false
        else {
            Logger.domain.warning("아우라픽 QR 토큰 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }

        let shootData = try await fetchShootData(urlCode: urlCode, qrCodeURL: qrCodeURL)
        let imageSourceURL = try imageSourceURL(from: shootData.urlFolderPath, qrCodeURL: qrCodeURL)
        let imageData = try await fetchImage(from: imageSourceURL)
        return ParsedQRResult(brand: .auraPic, originalImage: imageData)
    }
}


// MARK: - AuraPicStrategy + Networking

private extension AuraPicStrategy {
    func fetchShootData(
        urlCode: String,
        qrCodeURL: URL
    ) async throws(QRParseError) -> AuraPicShootDataDTO.Item {
        guard let endpointURL = makeURL(path: Constants.shootDataPath) else {
            Logger.domain.error("아우라픽 촬영 데이터 API URL 생성 실패.")
            throw .fallbackToWebView(qrCodeURL)
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(["urlCode": urlCode])
            let (data, response) = try await session.data(for: request, delegate: nil)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode)
            else {
                Logger.network.warning("아우라픽 촬영 데이터 조회 실패. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }

            let decodedResponse = try JSONDecoder().decode(AuraPicShootDataDTO.Response.self, from: data)
            guard decodedResponse.result else {
                Logger.domain.notice("아우라픽 촬영 데이터 조회 결과 없음. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }
            guard let shootData = decodedResponse.datas?.first else {
                Logger.data.error("아우라픽 촬영 데이터 응답 누락. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }
            return shootData
        } catch let error as QRParseError {
            throw error
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(error.code) {
            throw .networkError(.networkFail)
        } catch {
            Logger.network.error("아우라픽 촬영 데이터 파싱 실패: \(error.localizedDescription)")
            throw .fallbackToWebView(qrCodeURL)
        }
    }

    func fetchImage(from imageSourceURL: URL) async throws(QRParseError) -> Data {
        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageSourceURL), delegate: nil)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  data.isEmpty == false
            else {
                Logger.network.warning("아우라픽 이미지 다운로드 실패 또는 만료.")
                throw QRParseError.imageDownloadFailed
            }
            return data
        } catch let error as QRParseError {
            throw error
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(error.code) {
            throw .networkError(.networkFail)
        } catch {
            Logger.network.warning("아우라픽 이미지 다운로드 실패: \(error.localizedDescription)")
            throw .imageDownloadFailed
        }
    }
}


// MARK: - AuraPicStrategy + URL Construction

private extension AuraPicStrategy {
    func imageSourceURL(from folderPath: String, qrCodeURL: URL) throws(QRParseError) -> URL {
        let pathComponents = folderPath.split(separator: "/")
        guard folderPath.hasPrefix("/"),
              pathComponents.isEmpty == false,
              pathComponents.contains("..") == false
        else {
            Logger.domain.error("아우라픽 이미지 경로 검증 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }

        let imagePath = "\(Constants.imageBasePath)\(folderPath)/\(Constants.imageFileName)"
        guard let imageSourceURL = makeURL(path: imagePath) else {
            Logger.domain.error("아우라픽 이미지 URL 생성 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }
        return imageSourceURL
    }

    func makeURL(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Constants.host
        components.path = path
        return components.url
    }
}
