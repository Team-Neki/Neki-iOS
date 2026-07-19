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
    var supportedHosts: [String] { ["photoqr3.kr", "photosignature-viewer.web.app"] }

    init(session: URLSessionProtocol = URLSession.shared) { self.session = session }

    func parse(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
        Logger.data.debug("포토시그니처 파싱 시도: \(url.absoluteString)")
        
        if url.host() == "photosignature-viewer.web.app" {
            return try await parseViewerURL(url)
        }
        
        let urlString = url.absoluteString
        var imageURLString = String()
        
        if urlString.hasSuffix("index.html") {
            imageURLString = urlString.replacingOccurrences(of: "index.html", with: "a.jpg")
        } else {
            let cleanString = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
            imageURLString = cleanString + "/a.jpg"
        }
        
        guard let imageURL = URL(string: imageURLString) else {
            Logger.domain.error("이미지 URL 생성 실패.")
            throw .fallbackToWebView(url)
        }
        
        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageURL), delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) == false {
                Logger.domain.notice("이미지 다운로드 에러. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
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
    func parseViewerURL(_ url: URL) async throws(QRParseError) -> ParsedQRResult {
        guard let sessionID = sessionID(from: url) else {
            Logger.domain.warning("포토시그니처 뷰어 URL에서 sessionID 추출 실패. 웹뷰 폴백.")
            throw .fallbackToWebView(url)
        }
        
        guard let imageURL = URL(string: "https://photosignature-asset-cdn.photosignature.workers.dev/sessions/\(sessionID)/final.jpg") else {
            Logger.domain.error("포토시그니처 뷰어 이미지 URL 생성 실패.")
            throw .fallbackToWebView(url)
        }
        
        do {
            let (data, response) = try await session.data(for: URLRequest(url: imageURL), delegate: nil)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                Logger.domain.notice("포토시그니처 뷰어 이미지 다운로드 에러. 웹뷰 폴백.")
                throw QRParseError.fallbackToWebView(url)
            }
            
            return ParsedQRResult(brand: .photosignature, originalImage: data)
        } catch let error as QRParseError {
            throw error
        } catch {
            Logger.network.warning("포토시그니처 뷰어 이미지 없음(404 등). 만료 확인.")
            throw .imageDownloadFailed
        }
    }
    
    func sessionID(from url: URL) -> String? {
        if let fragment = url.fragment,
           let sessionID = sessionID(fromRoute: fragment) {
            return sessionID
        }
        
        return sessionID(fromRoute: url.path())
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
