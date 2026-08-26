//
//  PhotosignatureStrategy.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import Foundation
import os

struct PhotoSignatureStrategy: QRCodeParsingStrategy {
    private let session: URLSessionProtocol

    var strategyType: ParsingStrategyType { .native }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func canHandle(normalizedHost: String) -> Bool { QRCodeBrand.photosignature.hostKeywords.contains { normalizedHost.contains($0) } }

    func parse(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("포토시그니처 파싱 시도: \(qrCodeURL.absoluteString)")
        
        if qrCodeURL.host() == "photosignature-viewer.web.app" {
            return try await parseViewerURL(qrCodeURL)
        }
        
        let qrCodeURLString = qrCodeURL.absoluteString
        var imageSourceURLString = String()
        
        if qrCodeURLString.hasSuffix("index.html") {
            imageSourceURLString = qrCodeURLString.replacingOccurrences(of: "index.html", with: "a.jpg")
        } else {
            let cleanString = qrCodeURLString.hasSuffix("/") ? String(qrCodeURLString.dropLast()) : qrCodeURLString
            imageSourceURLString = cleanString + "/a.jpg"
        }
        
        guard let imageSourceURL = URL(string: imageSourceURLString) else {
            Logger.domain.error("이미지 URL 생성 실패.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageSourceURL), delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) == false {
                Logger.domain.notice("이미지 다운로드 에러. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }
            
            return ParsedQRResult(brand: .photosignature, originalImage: data)
            
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
}

private extension PhotoSignatureStrategy {
    func parseViewerURL(_ qrCodeURL: URL) async throws(QRParseError) -> ParsedQRResult {
        guard let sessionID = sessionID(from: qrCodeURL) else {
            Logger.domain.warning("포토시그니처 뷰어 URL에서 sessionID 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        guard let imageSourceURL = URL(string: "https://photosignature-asset-cdn.photosignature.workers.dev/sessions/\(sessionID)/final.jpg") else {
            Logger.domain.error("포토시그니처 뷰어 이미지 URL 생성 실패.")
            throw .fallbackToWebView(qrCodeURL)
        }
        
        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageSourceURL), delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                Logger.domain.notice("포토시그니처 뷰어 이미지 다운로드 에러. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(qrCodeURL)
            }
            
            return ParsedQRResult(brand: .photosignature, originalImage: data)
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("포토시그니처 뷰어 이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
    
    func sessionID(from qrCodeURL: URL) -> String? {
        if let fragment = qrCodeURL.fragment,
           let sessionID = sessionID(fromRoute: fragment) {
            return sessionID
        }
        
        return sessionID(fromRoute: qrCodeURL.path())
    }
    
    func sessionID(fromRoute route: String) -> String? {
        let routeWithoutQuery = route.split(separator: "?", maxSplits: 1).first.map(String.init) ?? route
        let pathComponents = routeWithoutQuery
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
        
        guard let viewIndex = pathComponents.firstIndex(of: "view") else { return nil }
        let sessionIDIndex = pathComponents.index(after: viewIndex)
        
        guard pathComponents.indices.contains(sessionIDIndex) else { return nil }
        return String(pathComponents[sessionIDIndex])
    }
}
