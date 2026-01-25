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

extension ArchiveImageItem {
    static func dummyData() -> [ArchiveImageItem] {
        func randomDate() -> Date {
            let day = Int.random(in: 1...28)
            let month = Int.random(in: 1...12)
            let components = DateComponents(year: 2025, month: month, day: day)
            return Calendar.current.date(from: components) ?? Date()
        }
        
        return [
            ArchiveImageItem(id: 1, imageURLString: "https://picsum.photos/200/300?random=1", isScrapped: true, date: randomDate()),
            ArchiveImageItem(id: 2, imageURLString: "https://picsum.photos/200/500?random=2", isScrapped: false, date: randomDate()),
            ArchiveImageItem(id: 3, imageURLString: "https://picsum.photos/300/300?random=3", isScrapped: false, date: randomDate()),
            ArchiveImageItem(id: 4, imageURLString: "https://picsum.photos/500/300?random=4", isScrapped: true, date: randomDate()),
            ArchiveImageItem(id: 5, imageURLString: "https://picsum.photos/200/500?random=5", isScrapped: false, date: randomDate()),
            ArchiveImageItem(id: 6, imageURLString: "https://picsum.photos/200/300?random=6", isScrapped: false, date: randomDate()),
            ArchiveImageItem(id: 7, imageURLString: "https://picsum.photos/700/300?random=7", isScrapped: false, date: randomDate()),
            ArchiveImageItem(id: 8, imageURLString: "https://picsum.photos/200/300?random=8", isScrapped: false, date: randomDate()),
            ArchiveImageItem(id: 9, imageURLString: "https://picsum.photos/200/500?random=9", isScrapped: false, date: randomDate()),
            ArchiveImageItem(id: 10, imageURLString: "https://picsum.photos/200/300?random=10", isScrapped: false, date: randomDate()),
        ]
    }
}
