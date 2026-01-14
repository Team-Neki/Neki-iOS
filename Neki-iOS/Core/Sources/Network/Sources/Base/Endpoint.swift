//
//  Endpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 12/29/25.
//

import Foundation

/// 인증 타입
public enum AuthorizationType {
    /// 별도의 인증이 필요하지 않은 경우
    case none
    /// Authorization-Bearer
    case bearer
    /// 토큰 재발급
    ///
    /// - Important: 토큰 재발급이라는 특수한 용도를 위한 설정입니다. 일반적인 요청에 사용하는 것은 권장하지 않습니다.
    /// - Authors: SwainYun
    case reissue
}

/// Content-Type 종류
public enum HTTPContentType {
    case json
    case multipart(boundary: String)
    case raw
}

public protocol Endpoint {
    var authorizationType: AuthorizationType { get }
    var contentType: HTTPContentType { get }
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethodType { get }
    var queryParameters: [String: String]? { get }
    var body: Encodable? { get }
    var multipartItems: [MultipartItem]? { get }
    
    func asURLRequest() throws -> URLRequest
}

extension Endpoint {
    public var queryParameters: [String: String]? { nil }
    
    public var multipartItems: [MultipartItem]? { nil }
    
    static let defaultEncoder: JSONEncoder = JSONEncoder()
    
    public func asURLRequest() throws -> URLRequest {
        let encoder = Self.defaultEncoder
        
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw NetworkError.invalidURLError
        }
        
        let currentPath = urlComponents.path
        urlComponents.path = currentPath + path
        
        if let queryParameters = queryParameters, !queryParameters.isEmpty {
            urlComponents.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURLError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        switch contentType {
        case .json:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let body = body { request.httpBody = try encoder.encode(body) }
            
        case .multipart(let boundary):
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var builder = MultipartItemBuilder(boundary: boundary)
            
            if let items = multipartItems {
                for item in items { try item.append(to: &builder) }
            }
            
            if let body = body {
                let data = try encoder.encode(body)
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw MultipartError.invalidBody
                }
                
                for (key, value) in dict {
                    let field = MultipartFormField(name: key, value: value)
                    try field.append(to: &builder)
                }
            }
            
            request.httpBody = try builder.finalize()
            
        case .raw:
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            guard let body = body as? Data else { throw MultipartError.invalidBody }
            request.httpBody = body
        }
        
        return request
    }
}
