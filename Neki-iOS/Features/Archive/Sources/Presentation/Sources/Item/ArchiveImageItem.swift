//
//  ArchiveImageItem.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import Foundation

struct ArchiveImageItem: Equatable, Identifiable {
    let id: Int
    let imageURL: URL?
    var isFavorite: Bool
    let date: Date
    var folderId: Int?
    var memo: String
    var width: Int?
    var height: Int?
    
    init(
        id: Int,
        imageURL: URL?,
        isFavorite: Bool = false,
        date: Date = Date(),
        folderId: Int? = nil,
        memo: String = "",
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.isFavorite = isFavorite
        self.date = date
        self.folderId = folderId
        self.memo = memo
        self.width = width
        self.height = height
    }
    
    init(
        id: Int,
        imageURLString: String,
        isFavorite: Bool = false,
        date: Date = Date(),
        folderId: Int? = nil,
        memo: String = "",
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.init(id: id, imageURL: URL(string: imageURLString), isFavorite: isFavorite, date: date, folderId: folderId, memo: memo, width: width, height: height)
    }
}
