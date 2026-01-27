//
//  ArchiveEndpoint.swift
//  Neki-iOS
//
//  Created by OneTen on 1/24/26.
//

import Foundation

public enum ArchiveEndpoint {
    case getPhotoList(request: PhotoListDTO.Request)
    case registerPhoto(request: RegisterPhotoDTO.Request)
    case deletePhoto(request: DeletePhotoRequestDTO)
    case getFavoriteAlbumInfo
    case getAlbumList
}

extension ArchiveEndpoint: Endpoint {
    public var authorizationType: AuthorizationType {
        switch self {
        default:
            return .bearer
        }
    }
    
    public var contentType: HTTPContentType {
        switch self {
        default:
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
        case .getFavoriteAlbumInfo:
            return "photos/favorite/summary"
        case .getAlbumList:
            return "folders"
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
        case .getFavoriteAlbumInfo:
            return .get
        case .getAlbumList:
            return .get
        }
    }
    
    public var body: (any Encodable)? {
        switch self {
        case .getPhotoList:
            return nil
        case .registerPhoto(let request):
            return request
        case .deletePhoto(let request):
            return request
        case .getFavoriteAlbumInfo:
            return nil
        case .getAlbumList:
            return nil
        }
    }
}
