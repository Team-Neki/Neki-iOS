//
//  ArchiveEndpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 1/24/26.
//

import Foundation

public enum ArchiveEndpoint {
    case getPhotoList(request: PhotoListDTO.Request)
    case registerPhoto(ids: [Int])
    case deletePhoto(ids: [Int])
}

extension ArchiveEndpoint: Endpoint {
    public var authorizationType: AuthorizationType {
        switch self {
        case .getPhotoList:
            return .bearer
        case .registerPhoto:
            return .bearer
        case .deletePhoto:
            return .bearer
        }
    }
    
    public var contentType: HTTPContentType {
        switch self {
        case .getPhotoList:
            return .json
        case .registerPhoto:
            return .json
        case .deletePhoto:
            return .json
        }
    }
    
    public var baseURL: String {
        switch self {
        default:
            guard let urlString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
                return NetworkError.invalidURLError.localizedDescription
            }
            return urlString
        }
    }
    
    public var path: String {
        switch self {
        case .getPhotoList:
            return "photos"
        case .registerPhoto:
            return "photos"
        case .deletePhoto:
            return "photos"
        }
    }
    
    public var queryParameters: [String: String]? {
        switch self {
        case .getPhotoList(let request):
            var params: [String: String] = [:]

            if let folderId = request.folderId { params["folderId"] = String(folderId) }
            if let page = request.page { params["page"] = String(page) }
            if let size = request.size { params["size"] = String(size) }
            if let sortOrder = request.sortOrder { params["sortOrder"] = sortOrder }
            
            return params.isEmpty ? nil : params
            
        default:
            return nil
        }
    }
    
    public var method: HTTPMethodType {
        switch self {
        case .getPhotoList:
            return .get
        case .registerPhoto:
            return .post
        case .deletePhoto:
            return .delete
        }
    }
    
    public var body: (any Encodable)? {
        switch self {
        case .getPhotoList:
            return nil
        case .registerPhoto:
            return nil
        case .deletePhoto:
            return nil
        }
    }
}
