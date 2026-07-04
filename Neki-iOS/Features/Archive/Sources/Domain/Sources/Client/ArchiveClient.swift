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
    public var refreshPhotos: (_ scope: ArchivePhotoScope, _ size: Int?, _ sortOrder: ArchivePhotoSortOrder?) async throws -> ArchivePhotoSnapshot
    public var fetchNextPhotos: (_ scope: ArchivePhotoScope, _ size: Int?, _ sortOrder: ArchivePhotoSortOrder?) async throws -> ArchivePhotoSnapshot
    public var getAlbumList: () async throws -> [AlbumEntity]
    public var deletePhotoList: (_ photoIds: [Int]) async throws -> Void
    public var registerPhotos: (_ folderId: Int?, _ uploads: [(mediaID: Int, memo: String?, uploadMethod: PhotoUploadMethod)], _ favorite: Bool?) async throws -> Void
    public var getFavoriteAlbumInfo: () async throws -> FavoriteAlbumEntity
    public var addFolder: (_ name: String) async throws -> Int
    public var deleteFolders: (_ folderIDs: [Int], _ deletePhotos: Bool) async throws -> Void
    public var toggleFavorite: (_ photoID: Int, _ request: Bool) async throws -> Void
    public var excludePhotosInAlbum: (_ albumID: Int, _ photoIDs: [Int]) async throws -> Void
    public var editAlbumName: (_ albumID: Int, _ name: String) async throws -> Void
    public var updatePhotoMemo: (_ photoID: Int, _ memo: String) async throws -> Void
    public var clearCache: () async throws -> Void
    public var duplicatePhoto: (_ photoIDs: [Int], _ targetFolderIDs: [Int]) async throws -> Void
    public var movePhoto: (_ sourceFolderId: Int, _ photoIDs: [Int], _ targetFolderIDs: [Int]) async throws -> Void
}

extension ArchiveClient: DependencyKey {
    static var liveValue: ArchiveClient {
        @Dependency(\.archiveRepository) var archiveRepository
        
        return ArchiveClient(
            refreshPhotos: { scope, size, sortOrder in
                try await archiveRepository.refreshPhotos(scope: scope, size: size, sortOrder: sortOrder)
            },
            fetchNextPhotos: { scope, size, sortOrder in
                try await archiveRepository.fetchNextPhotos(scope: scope, size: size, sortOrder: sortOrder)
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
            },
            duplicatePhoto: { photoIDs, targetFolderIDs in
                try await archiveRepository.duplicatePhoto(photoIDs: photoIDs, targetFolderIDs: targetFolderIDs)
            },
            movePhoto: { sourceFolderId, photoIDs, targetFolderIDs in
                try await archiveRepository.movePhoto(sourceFolderId: sourceFolderId, photoIDs: photoIDs, targetFolderIDs: targetFolderIDs)
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
