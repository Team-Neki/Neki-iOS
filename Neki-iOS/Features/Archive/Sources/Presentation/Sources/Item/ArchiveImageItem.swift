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
    
    init(id: Int, imageURL: URL?, isFavorite: Bool = false, date: Date = Date(), folderId: Int? = nil, memo: String = "") {
        self.id = id
        self.imageURL = imageURL
        self.isFavorite = isFavorite
        self.date = date
        self.folderId = folderId
        self.memo = memo
    }
        
    init(id: Int, imageURLString: String, isFavorite: Bool = false, date: Date = Date(), folderId: Int? = nil, memo: String = "") {
        self.init(id: id, imageURL: URL(string: imageURLString), isFavorite: isFavorite, date: date, folderId: folderId, memo: memo)
    }
}
