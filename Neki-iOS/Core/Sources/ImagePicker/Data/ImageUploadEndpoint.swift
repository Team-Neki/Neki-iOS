//
//  ImageUploadEndpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public enum ImageUploadEndpoint: Endpoint {
    case getPresignedURL(request: PresignedURLRequestDTO)
    case uploadToS3(presignedURL: String, data: Data, contentType: String)
}

extension ImageUploadEndpoint {
    
    public var baseURL: String {
        switch self {
        case .getPresignedURL:
            guard let urlString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
                return NetworkError.invalidURLError.localizedDescription
            }
            return urlString
            
        case .uploadToS3(let presignedURL, _, _):
            return presignedURL
        }
    }
    
    public var path: String {
        switch self {
        case .getPresignedURL:
            return "media/upload"
        case .uploadToS3:
            return ""
        }
    }
    
    public var method: HTTPMethodType {
        switch self {
        case .getPresignedURL:
            return .post
        case .uploadToS3:
            return .put
        }
    }
    
    public var authorizationType: AuthorizationType {
        switch self {
        case .getPresignedURL:
            return .bearer
        case .uploadToS3:
            return .none
        }
    }
    
    public var contentType: HTTPContentType {
        switch self {
        case .getPresignedURL:
            return .json
        case .uploadToS3(_, _, let contentType):
            return .custom(contentType)
        }
    }
    
    public var body: Encodable? {
        switch self {
        case .getPresignedURL(let request):
            return request
        case .uploadToS3(_, let data, _):
            return data
        }
    }
}
