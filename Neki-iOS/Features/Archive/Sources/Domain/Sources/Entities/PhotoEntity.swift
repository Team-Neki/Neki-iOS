//
//  PhotoEntity.swift
//  Neki-iOS
//
//  Created by OneTen on 1/26/26.
//

import Foundation

struct PhotoEntity: Equatable, Identifiable, Sendable {
    let id: Int
    let imageURL: URL?
    let folderID: Int?
    var isFavorite: Bool
    let contentType: String
    let createdAt: Date
    var memo: String
    let width: Int?
    let height: Int?

    init(
        id: Int,
        imageURL: URL?,
        isFavorite: Bool = false,
        createdAt: Date,
        folderID: Int? = nil,
        memo: String = "",
        width: Int? = nil,
        height: Int? = nil,
        contentType: String = ""
    ) {
        self.id = id
        self.imageURL = imageURL
        self.folderID = folderID
        self.isFavorite = isFavorite
        self.contentType = contentType
        self.createdAt = createdAt
        self.memo = memo
        self.width = width
        self.height = height
    }
}
