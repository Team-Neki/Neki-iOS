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
    case addFolder(request: FolderDTO.Request)
    case deleteFolders(request: DeleteFoldersRequestDTO, deletePhotos: Bool)
    case getFavoritePhotoList(request: PhotoListDTO.Request)
    case toggleFavorite(photoID: Int, request: ToggleFavoriteDTO)
    case excludePhotosInAlbum(albumID: Int, request: DeletePhotoRequestDTO)
    case editFolderName(albumID: Int, request: FolderDTO.Request)
    case updateMemo(photoID: Int, request: UpdateMemoRequestDTO)
}

extension ArchiveEndpoint: Endpoint {
    
    public var authorizationType: AuthorizationType { return .bearer }
    
    public var contentType: HTTPContentType { return .json }
    
    public var baseURL: String {
        guard let urlString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
            return NetworkError.invalidURLError.localizedDescription
        }
        return urlString
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
        case .addFolder:
            return "folders"
        case .deleteFolders:
            return "folders"
        case .getFavoritePhotoList:
            return "photos/favorite"
        case .toggleFavorite(let id, _):
            return "photos/\(id)/favorite"
        case .excludePhotosInAlbum(let albumID, _):
            return "folders/\(albumID)/photos"
        case .editFolderName(let albumID, _):
            return "folders/\(albumID)"
        case .updateMemo(let id, _):
            return "photos/\(id)"
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
            
        case .getFavoritePhotoList(let request):
            var params: [String: String] = [:]
            
            if let page = request.page { params["page"] = String(page) }
            if let size = request.size { params["size"] = String(size) }
            if let sortOrder = request.sortOrder { params["sortOrder"] = sortOrder }
            
            return params.isEmpty ? nil : params
            
        case .deleteFolders(_, let deletePhotos):
            var params: [String: String] = [:]
            params["deletePhotos"] = "\(deletePhotos.description)"
            
            return params
            
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
        case .addFolder:
            return .post
        case .deleteFolders:
            return .delete
        case .getFavoritePhotoList:
            return .get
        case .toggleFavorite:
            return .patch
        case .excludePhotosInAlbum:
            return .delete
        case .editFolderName:
            return .patch
        case .updateMemo:
            return .put
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
        case .addFolder(let request):
            return request
        case .deleteFolders(let request, _):
            return request
        case .getFavoritePhotoList:
            return nil
        case .toggleFavorite(_, let request):
            return request
        case .excludePhotosInAlbum(_, let request):
            return request
        case .editFolderName(_, let request):
            return request
        case .updateMemo(_, let request):
            return request
        }
    }
}
