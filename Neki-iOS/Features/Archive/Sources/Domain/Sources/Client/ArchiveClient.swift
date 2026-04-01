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
    public var fetchPhotoList: (_ folderId: Int?, _ size: Int?, _ sortOrder: String?) async throws -> [PhotoEntity]
    public var getAlbumList: () async throws -> [AlbumEntity]
    public var deletePhotoList: (_ photoIds: [Int]) async throws -> Void
    public var registerPhotos: (_ folderId: Int?, _ uploads: [(mediaID: Int, memo: String?, uploadMethod: PhotoUploadMethod)], _ favorite: Bool?) async throws -> Void
    public var getFavoriteAlbumInfo: () async throws -> FavoriteAlbumEntity
    public var addFolder: (_ name: String) async throws -> Int
    public var deleteFolders: (_ folderIDs: [Int], _ deletePhotos: Bool) async throws -> Void
    public var fetchFavoritePhotoList: (_ size: Int?, _ sortOrder: String?) async throws -> [PhotoEntity]
    public var toggleFavorite: (_ photoID: Int, _ request: Bool) async throws -> Void
    public var excludePhotosInAlbum: (_ albumID: Int, _ photoIDs: [Int]) async throws -> Void
    public var editAlbumName: (_ albumID: Int, _ name: String) async throws -> Void
    public var updatePhotoMemo: (_ photoID: Int, _ memo: String) async throws -> Void
    public var clearCache: () async -> Void
}

extension ArchiveClient: DependencyKey {
    static var liveValue: ArchiveClient {
        @Dependency(\.archiveRepository) var archiveRepository
        
        return ArchiveClient(
            fetchPhotoList: { folderId, size, sortOrder in
                try await archiveRepository.fetchPhotoList(folderID: folderId, size: size, sortOrder: sortOrder)
            },
            getAlbumList: {
                try await archiveRepository.getAlbumList()
            },
            deletePhotoList: { photoIds in
                try await archiveRepository.deletePhotoList(photoIDs: photoIds)
            },
            registerPhotos: { folderId, uploads, favorite in
                try await archiveRepository.registerPhoto(folderID: folderId, uploads: uploads, favorite: favorite)
            },
            getFavoriteAlbumInfo: {
                try await archiveRepository.getFavoriteAlbumInfo()
            },
            addFolder: { name in
                try await archiveRepository.addFolder(name: name)
            },
            deleteFolders: { folderIDs, deletePhotos in
                try await archiveRepository.deleteFolders(folderIDs: folderIDs, deletePhotos: deletePhotos)
            },
            fetchFavoritePhotoList: { size, sortOrder in
                try await archiveRepository.fetchFavoritePhotoList(size: size, sortOrder: sortOrder)
            },
            toggleFavorite: { photoID, request in
                try await archiveRepository.toggleFavorite(photoID: photoID, request: request)
            },
            excludePhotosInAlbum: { albumID, photoIDs in
                try await archiveRepository.excludePhotosInAlbum(albumID: albumID, photoIDs: photoIDs)
            },
            editAlbumName: { albumID, name in
                try await archiveRepository.editAlbumName(albumID: albumID, name: name)
            },
            updatePhotoMemo: { photoID, memo in
                try await archiveRepository.updatePhotoMemo(photoID: photoID, memo: memo)
            },
            clearCache: {
                await archiveRepository.clearCache()
            }
        )
    }
}

extension DependencyValues {
    var archiveClient: ArchiveClient {
        get { self[ArchiveClient.self] }
        set { self[ArchiveClient.self] = newValue }
    }
}
