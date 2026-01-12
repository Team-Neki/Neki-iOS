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
}

public protocol Endpoint {
    var authorizationType: AuthorizationType { get }
    var contentType: HTTPContentType { get }
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethodType { get }
    var body: Encodable? { get }
    
    func asURLRequest() throws -> URLRequest
}

extension Endpoint {
    static var defaultEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        return encoder
    }
    
    public func asURLRequest() throws -> URLRequest {
        guard let url = URL(string: baseURL)?.appending(path: path) else {
            throw NetworkError.invalidURLError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        switch contentType {
        case .json:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        case .multipart(let boundary):
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        }
        
        if let body {
            switch contentType {
            case .json:
                request.httpBody = try Self.defaultEncoder.encode(body)
                
            case .multipart(let boundary):
                // TODO: MultipartBuilder 구현..
                if let data = body as? Data {
                    request.httpBody = data
                } else {
                    throw NetworkError.requestEncodingError
                }
            }
        }
        
        return request
    }
}
