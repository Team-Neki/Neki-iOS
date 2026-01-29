//
//  DefaultArchiveRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/25/26.
//

import Foundation
import Dependencies

struct DefaultArchiveRepository: ArchiveRepository {
    @Dependency(\.networkProvider) var networkProvider
    
    func fetchPhotoList(folderID: Int?, page: Int?, size: Int?, sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool) {
        let request = PhotoListDTO.Request(folderId: folderID, page: page, size: size, sortOrder: sortOrder)
        let endpoint = ArchiveEndpoint.getPhotoList(request: request)
        let response: BaseResponseDTO<PhotoListDTO.PhotoListData> = try await networkProvider.request(endpoint: endpoint)
        
        guard let data = response.data else { throw NetworkError.responseDecodingError }
        
        let entities = data.toEntity()
        
        return (entities, data.hasNext)
    }
    
    func deletePhotoList(photoIDs: [Int]) async throws {
        let request = DeletePhotoRequestDTO(photoIds: photoIDs)
        let endpoint = ArchiveEndpoint.deletePhoto(request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
    }
    
    func registerPhoto(folderID: Int?, uploads: [(mediaID: Int, memo: String?)]) async throws {
        let uploadData: [RegisterPhotoDTO.RegisterPhotoData] = uploads.map {
                    RegisterPhotoDTO.RegisterPhotoData(
                        mediaID: $0.mediaID,
                        memo: $0.memo
                    )
                }
        
        let request = RegisterPhotoDTO.Request(folderID: folderID, uploads: uploadData)
        let endpoint = ArchiveEndpoint.registerPhoto(request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
        
    }
    
    func getFavoriteAlbumInfo() async throws -> FavoriteAlbumEntity {
        let result: BaseResponseDTO<FavoriteAlbumInfoDTO> = try await networkProvider.request(endpoint: ArchiveEndpoint.getFavoriteAlbumInfo)
        
        guard let data = result.data else {
            throw NetworkError.responseDecodingError
        }
        
        let entity: FavoriteAlbumEntity = FavoriteAlbumEntity(latestImageURL: data.latestImageURL ?? "", totalCount: data.totalCount)
        
        
        
        return entity
    }
    
    func getAlbumList() async throws -> [AlbumEntity] {
        let result: BaseResponseDTO<AlbumInfoDTO> = try await networkProvider.request(endpoint: ArchiveEndpoint.getAlbumList)
        
        guard let data = result.data else {
            throw NetworkError.responseDecodingError
        }
        
        let entities: [AlbumEntity] = data.items.map {
            AlbumEntity(id: $0.folderID, name: $0.name, photoCount: $0.totalCount, coverImageURLString: $0.latestImageURL ?? "")
        }
        
        return entities
    }
    
    func addFolder(name: String) async throws -> Int {
        let request = AddFolderDTO.Request(name: name)
        let result: BaseResponseDTO<AddFolderDTO.Response> = try await networkProvider.request(endpoint: ArchiveEndpoint.addFolder(request: request))
        
        guard let data = result.data else { throw NetworkError.responseDecodingError }
        
        return data.folderId
    }
    
    func deleteFolders(folderIDs: [Int]) async throws {
        let request = DeleteFoldersRequestDTO(folderIds: folderIDs)
        let endpoint = ArchiveEndpoint.deleteFolders(request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
    }
    
    func fetchFavoritePhotoList(page: Int?, size: Int?, sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool) {
        let request = PhotoListDTO.Request(folderId: nil, page: page, size: size, sortOrder: sortOrder)
        let endpoint = ArchiveEndpoint.getFavoritePhotoList(request: request)
        let response: BaseResponseDTO<PhotoListDTO.PhotoListData> = try await networkProvider.request(endpoint: endpoint)
        
        guard let data = response.data else { throw NetworkError.responseDecodingError }
        
        let entities = data.toEntity()
        
        return (entities, data.hasNext)
    }
    
    func toggleFavorite(photoID: Int, request: Bool) async throws {
        let request = ToggleFavoriteDTO(favorite: request)
        let endpoint = ArchiveEndpoint.toggleFavorite(photoID: photoID, request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
    }
}

private enum ArchiveRepositoryKey: DependencyKey {
    static let liveValue: ArchiveRepository = DefaultArchiveRepository()
}

extension DependencyValues {
    var archiveRepository: ArchiveRepository {
        get { self[ArchiveRepositoryKey.self] }
        set { self[ArchiveRepositoryKey.self] = newValue }
    }
}
