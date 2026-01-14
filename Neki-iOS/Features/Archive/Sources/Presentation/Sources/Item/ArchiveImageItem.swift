//
//  ArchiveImageItem.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import Foundation

struct ArchiveImageItem: Equatable, Identifiable {
    let id: UUID
    let imageURL: URL?
    
    init(id: UUID, imageURLString: String) {
        self.id = id
        self.imageURL = URL(string: imageURLString)
    }
    
    init(id: UUID, imageURL: URL) {
        self.id = id
        self.imageURL = imageURL
    }
}

extension ArchiveImageItem {
    static func dummyData() -> [ArchiveImageItem] {
        return [
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(1)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(200)/\(500)?random=\(2)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(300)?random=\(3)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(800)?random=\(4)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(500)/\(500)?random=\(5)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(700)/\(500)?random=\(6)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(900)?random=\(7)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(100)?random=\(8)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(200)/\(500)?random=\(9)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(10)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(11)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(12)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(13)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(14)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(15)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(16)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(17)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(18)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(19)"),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/\(300)/\(500)?random=\(20)")
        ]
    }
    
    func toFeedImageItem() -> FeedImageItem {
        return FeedImageItem(id: id, imageURL: imageURL!)
    }
}
