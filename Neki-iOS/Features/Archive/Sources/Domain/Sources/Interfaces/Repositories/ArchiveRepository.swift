//
//  ArchiveRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/25/26.
//

import Foundation

protocol ArchiveRepository {
    func fetchPhotoList(folderID: Int?, page: Int?, size: Int?, sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool)
    func deletePhotoList(photoIDs: [Int]) async throws
    func registerPhoto(folderID: Int?, uploads: [(mediaID: Int, memo: String?)]) async throws
    func getFavoriteAlbumInfo() async throws -> FavoriteAlbumEntity
    func getAlbumList() async throws -> [AlbumEntity]
    func addFolder(name: String) async throws -> Int
    func deleteFolders(folderIDs: [Int]) async throws
    func fetchFavoritePhotoList(page: Int?, size: Int?, sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool)
    func toggleFavorite(photoID: Int, request: Bool) async throws
}
