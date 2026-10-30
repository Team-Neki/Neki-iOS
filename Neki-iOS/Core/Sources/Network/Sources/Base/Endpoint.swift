//
//  Endpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 12/29/25.
//

import Foundation
import os
import UniformTypeIdentifiers

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
    case custom(String)
}

public enum NetworkLogPolicy {
    case standard
    case metadataOnly
}

public struct HTTPResponseConstraint: Sendable, Equatable {
    public let allowedContentTypes: Set<UTType>
    public let maximumBodySize: Int64?

    public init(allowedContentTypes: Set<UTType>, maximumBodySize: Int64? = nil) {
        self.allowedContentTypes = allowedContentTypes
        self.maximumBodySize = maximumBodySize
    }
}

public protocol RequestEndpoint {
    var contentType: HTTPContentType { get }
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethodType { get }
    var queryParameters: [String: String]? { get }
    var body: Encodable? { get }
    var multipartItems: [MultipartItem]? { get }
    var networkLogPolicy: NetworkLogPolicy { get }
    var allowsConstrainedNetworkAccess: Bool { get }
    
    func asURLRequest() throws -> URLRequest
}

public protocol Endpoint: RequestEndpoint {
    var credentialOperation: CredentialOperation { get }
    var authorizationType: AuthorizationType { get }
}

public protocol FileTransferEndpoint: RequestEndpoint {}

public protocol FileDownloadEndpoint: FileTransferEndpoint {
    var responseConstraint: HTTPResponseConstraint { get }
}

public protocol FileUploadEndpoint: FileTransferEndpoint {}

extension RequestEndpoint {
    public var baseURL: String {
        guard let baseURLString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
            Logger.data.fault("Base URL not found in Bundle")
            fatalError()
        }
        return baseURLString
    }
    
    public var queryParameters: [String: String]? { nil }
    
    public var multipartItems: [MultipartItem]? { nil }

    public var networkLogPolicy: NetworkLogPolicy { .standard }

    public var allowsConstrainedNetworkAccess: Bool { true }

    static var defaultEncoder: JSONEncoder { JSONEncoder() }
    
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
        request.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
        
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
            
        case .custom(let contentType):
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            
            if let bodyData = body as? Data {
                request.httpBody = bodyData
            } else if let body = body {
                request.httpBody = try encoder.encode(body)
            }
        }
        
        return request
    }
}

extension FileTransferEndpoint {
    public var allowsConstrainedNetworkAccess: Bool { false }
}

extension Endpoint {
    public var credentialOperation: CredentialOperation { .none }
}
