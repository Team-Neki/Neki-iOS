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
    let folderId: Int?
    
    init(id: Int, imageURL: URL?, isScrapped: Bool = false, date: Date = Date(), folderId: Int? = nil) {
            self.id = id
            self.imageURL = imageURL
            self.isFavorite = isScrapped
            self.date = date
            self.folderId = folderId
        }
        
        init(id: Int, imageURLString: String, isScrapped: Bool = false, date: Date = Date(), folderId: Int? = nil) {
            self.init(id: id, imageURL: URL(string: imageURLString), isScrapped: isScrapped, date: date, folderId: folderId)
        }
}
