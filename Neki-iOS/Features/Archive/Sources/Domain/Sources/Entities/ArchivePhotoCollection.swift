//
//  ArchivePhotoCollection.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/3/26.
//

import Foundation

enum ArchivePhotoScope: Hashable, Sendable {
    case all
    case album(Int)
    case favorites

    var folderID: Int? {
        guard case let .album(id) = self else { return nil }
        return id
    }
}

enum ArchivePhotoSortOrder: String, Equatable, Sendable {
    case ascending = "ASC"
    case descending = "DESC"
}

struct ArchivePhotoSnapshot: Equatable, Sendable {
    let photos: [PhotoEntity]
    let totalCount: Int
    let hasNext: Bool
}
