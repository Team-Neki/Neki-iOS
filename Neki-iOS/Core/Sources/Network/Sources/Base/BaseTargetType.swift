//
//  EndPoint.swift
//  Neki-iOS
//
//  Created by OneTen on 12/29/25.
//

import Foundation

public enum HeaderType {
    case noneHeader
    case accessTokenHeader
    case refreshTokenHeader
}

public protocol BaseTargetType {
    var baseURL: String { get }
    var headerType: HeaderType { get }
    var path: String { get }
    var method: HTTPMethodType { get }
    var body: Encodable? { get }
    var queryItems: [URLQueryItem]? { get }
}

extension BaseTargetType {
    
    var baseURL: String {
        guard let urlString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
            fatalError("🚨Base URL을 찾을 수 없습니다🚨")
        }
        return urlString
    }
    
    func makeURLRequest() throws -> URLRequest {
        // URLComponents를 이용한 초기 URL 생성
        guard let url = URL(string: baseURL)?.appending(path: path),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { throw NetworkError.invalidURLError }
        
        // 쿼리 아이템이 있으면 추가
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }
        
        // 쿼리아이템이 추가된 최종 URL 생성
        guard let finalURL = components.url else { throw NetworkError.invalidURLError }
        
        // Request 생성
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.key
        
        // 헤더 설정
        let allHeaders = makeHeaders()
        for (key, value) in allHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Body 인코딩
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.requestEncodingError
            }
        }
        
        return request
    }
    
    private func makeHeaders() -> [String: String] {
        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]
        
        switch headerType {
        case .noneHeader:
            break
        case .accessTokenHeader:
            // TODO: - 여기에 토큰 가져오는 로직 추가 (토큰매니저나 키체인매니저 등)
            break
        case .refreshTokenHeader:
            // TODO: - 리프레시 토큰 로직 추가
            break
        }
        
        return headers
    }
    
}
