//
//  Endpoint.swift
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

public protocol Endpoint {
    var headerType: HeaderType { get }
    var path: String { get }
    var method: HTTPMethodType { get }
    var body: Encodable? { get }
    var query: [URLQueryItem]? { get }
    
    func asURLRequest() throws -> URLRequest
}

extension Endpoint {
    static var defaultEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        return encoder
    }
    
    var baseURL: String {
        guard let urlString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
            fatalError("🚨Base URL을 찾을 수 없습니다🚨")
        }
        return urlString
    }
    
    public func asURLRequest() throws -> URLRequest {
        guard let url = URL(string: baseURL)?.appending(path: path),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw NetworkError.invalidURLError
        }
        
        if let query = query {
            components.queryItems = query
        }
        
        guard let finalURL = components.url else {
            throw NetworkError.invalidURLError
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        
        let allHeaders = makeHeaders()
        request.allHTTPHeaderFields = allHeaders
        
        if let body = body {
            do {
                request.httpBody = try Self.defaultEncoder.encode(body)
            } catch {
                throw NetworkError.requestEncodingError
            }
        }
        
        return request
    }
    
    
    // TODO: - "Content-Type"외 다양한 헤더를 추가할 수 있도록 하기
    func makeHeaders() -> [String: String] {
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
