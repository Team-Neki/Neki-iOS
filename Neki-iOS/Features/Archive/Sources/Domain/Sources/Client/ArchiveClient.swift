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
}

extension ArchiveClient: DependencyKey {
    static var liveValue: ArchiveClient {
        @Dependency(\.archiveRepository) var archiveRepository
        
        func fetchPhotoList(_ folderId: Int?, _ page: Int?, _ size: Int?, _ sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool) {
            let result = try await archiveRepository.fetchPhotoList(folderID: folderId, page: page, size: size, sortOrder: sortOrder)
            
            return result
        }
        
        func deletePhotoList(_ photoIds: [Int]) async throws {
            _ = try await archiveRepository.deletePhotoList(photoIDs: photoIds)
        }
        
        return ArchiveClient(fetchPhotoList: fetchPhotoList, deletePhotoList: deletePhotoList)
    }
}

extension DependencyValues {
    var archiveClient: ArchiveClient {
        get { self[ArchiveClient.self] }
        set { self[ArchiveClient.self] = newValue }
    }
}
