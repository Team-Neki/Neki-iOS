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
}
