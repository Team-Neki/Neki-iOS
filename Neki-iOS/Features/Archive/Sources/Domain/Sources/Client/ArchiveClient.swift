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
    public var addFolder: (_ name: String) async throws -> Int
    public var deleteFolders: (_ folderIDs: [Int], _ deletePhotos: Bool) async throws -> Void
    public var fetchFavoritePhotoList: (_ page: Int?, _ size: Int?, _ sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool)
    public var toggleFavorite: (_ photoID: Int, _ request: Bool) async throws -> Void
    public var excludePhotosInAlbum: (_ albumID: Int, _ photoIDs: [Int]) async throws -> Void
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

        func addFolder(name: String) async throws -> Int {
            return try await archiveRepository.addFolder(name: name)
        }
        
        func deleteFolders(folderIDs: [Int], deletePhotos: Bool) async throws -> Void {
            return try await archiveRepository.deleteFolders(folderIDs: folderIDs, deletePhotos: deletePhotos)
        }

        func fetchFavoritePhotoList(_ page: Int?, _ size: Int?, _ sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool) {
            let result = try await archiveRepository.fetchFavoritePhotoList(page: page, size: size, sortOrder: sortOrder)
            
            return result
        }
        
        func toggleFavorite(photoID: Int, request: Bool) async throws -> Void {
            return try await archiveRepository.toggleFavorite(photoID: photoID, request: request)
        }
        
        func excludePhotosInAlbum(albumID: Int, photoIDs: [Int]) async throws -> Void {
            try await archiveRepository.excludePhotosInAlbum(albumID: albumID, photoIDs: photoIDs)
        }
        
        return ArchiveClient(
            fetchPhotoList: fetchPhotoList,
            deletePhotoList: deletePhotoList,
            registerPhotos: registerPhotos,
            getFavoriteAlbumInfo: getFavoriteAlbumInfo,
            getAlbumList: getAlbumList,
            addFolder: addFolder,
            deleteFolders: deleteFolders,
            fetchFavoritePhotoList: fetchFavoritePhotoList,
            toggleFavorite: toggleFavorite,
            excludePhotosInAlbum: excludePhotosInAlbum
        )
    }
}

extension DependencyValues {
    var archiveClient: ArchiveClient {
        get { self[ArchiveClient.self] }
        set { self[ArchiveClient.self] = newValue }
    }
}
