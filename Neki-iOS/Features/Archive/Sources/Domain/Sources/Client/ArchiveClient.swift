//
//  ArchiveClient.swift
//  Neki-iOS
//
//  Created by OneTen on 1/26/26.
//

import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
struct ArchiveClient {
    public var fetchPhotoList: (_ folderId: Int?, _ page: Int?, _ size: Int?, _ sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool)
    public var deletePhotoList: (_ photoIds: [Int]) async throws -> Void
    public var registerPhotos: (_ folderId: Int?, _ uploads: [(mediaID: Int, memo: String?)]) async throws -> Void
    public var getFavoriteAlbumInfo: () async throws -> FavoriteAlbumEntity
    public var getAlbumList: () async throws -> [AlbumEntity]

}

extension ArchiveClient: DependencyKey {
    static var liveValue: ArchiveClient {
        @Dependency(\.archiveRepository) var archiveRepository
        
        func fetchPhotoList(_ folderId: Int?, _ page: Int?, _ size: Int?, _ sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool) {
            let result = try await archiveRepository.fetchPhotoList(folderID: folderId, page: page, size: size, sortOrder: sortOrder)
            
            return result
        }
        
        func deletePhotoList(_ photoIds: [Int]) async throws {
            try await archiveRepository.deletePhotoList(photoIDs: photoIds)
        }
        
        func registerPhotos(_ folderId: Int?, _ uploads: [(mediaID: Int, memo: String?)]) async throws {
            try await archiveRepository.registerPhoto(folderID: folderId, uploads: uploads)
        }
        
        func getFavoriteAlbumInfo() async throws -> FavoriteAlbumEntity {
            return try await archiveRepository.getFavoriteAlbumInfo()
        }
        
        func getAlbumList() async throws -> [AlbumEntity] {
            return try await archiveRepository.getAlbumList()
        }

        
        return ArchiveClient(
            fetchPhotoList: fetchPhotoList,
            deletePhotoList: deletePhotoList,
            registerPhotos: registerPhotos,
            getFavoriteAlbumInfo: getFavoriteAlbumInfo,
            getAlbumList: getAlbumList
        )
    }
}

extension DependencyValues {
    var archiveClient: ArchiveClient {
        get { self[ArchiveClient.self] }
        set { self[ArchiveClient.self] = newValue }
    }
}
