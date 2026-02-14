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
    func registerPhoto(folderID: Int?, uploads: [(mediaID: Int, memo: String?)]) async throws
    
    // Read
    func fetchPhotoList(folderID: Int?, size: Int?, sortOrder: String?) async throws -> [PhotoEntity]
    func getAlbumList() async throws -> [AlbumEntity]
    func getFavoriteAlbumInfo() async throws -> FavoriteAlbumEntity
    func fetchFavoritePhotoList(size: Int?, sortOrder: String?) async throws -> [PhotoEntity]
    
    // Update
    func toggleFavorite(photoID: Int, request: Bool) async throws
    func excludePhotosInAlbum(albumID: Int, photoIDs: [Int]) async throws
    
    // Delete
    func deletePhotoList(photoIDs: [Int]) async throws
    func deleteFolders(folderIDs: [Int], deletePhotos: Bool) async throws
}
