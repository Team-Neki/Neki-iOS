//
//  ArchiveRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/25/26.
//

import Foundation

protocol ArchiveRepository: Sendable {
    // Create
    func addFolder(name: String) async throws -> Int
    func registerPhoto(folderID: Int?, uploads: [(mediaID: Int, memo: String?, uploadMethod: PhotoUploadMethod)], favorite: Bool?) async throws
    
    // Read
    func refreshPhotos(scope: ArchivePhotoScope, size: Int?, sortOrder: ArchivePhotoSortOrder?) async throws -> ArchivePhotoSnapshot
    func fetchNextPhotos(scope: ArchivePhotoScope, size: Int?, sortOrder: ArchivePhotoSortOrder?) async throws -> ArchivePhotoSnapshot
    func getAlbumList() async throws -> [AlbumEntity]
    func getFavoriteAlbumInfo() async throws -> FavoriteAlbumEntity
    
    // Update
    func toggleFavorite(photoID: Int, request: Bool) async throws
    func excludePhotosInAlbum(albumID: Int, photoIDs: [Int]) async throws
    func editAlbumName(albumID: Int, name: String) async throws
    func updatePhotoMemo(photoID: Int, memo: String) async throws
    func duplicatePhoto(photoIDs: [Int], targetFolderIDs: [Int]) async throws
    func movePhoto(sourceFolderId: Int, photoIDs: [Int], targetFolderIDs: [Int]) async throws
    
    // Delete
    func deletePhotoList(photoIDs: [Int]) async throws
    func deleteFolders(folderIDs: [Int], deletePhotos: Bool) async throws
    func clearCache() async
}

public enum PhotoUploadMethod: String, Sendable {
    case qr = "QR"
    case direct = "DIRECT_UPLOAD"
}
