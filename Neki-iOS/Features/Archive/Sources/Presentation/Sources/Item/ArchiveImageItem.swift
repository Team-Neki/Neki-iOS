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
    var isScrapped: Bool
    
    init(id: UUID, imageURL: URL?, isScrapped: Bool = false) {
        self.id = id
        self.imageURL = imageURL
        self.isScrapped = isScrapped
    }
    
    init(id: UUID, imageURLString: String, isScrapped: Bool = false) {
        self.init(id: id, imageURL: URL(string: imageURLString), isScrapped: isScrapped)
    }
}

extension ArchiveImageItem {
    static func dummyData() -> [ArchiveImageItem] {
        return [
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=1", isScrapped: true),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/500?random=2", isScrapped: false),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/300/300?random=3", isScrapped: false),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/500/300?random=4", isScrapped: true),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/500?random=5", isScrapped: false),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=6", isScrapped: false),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/700/300?random=7", isScrapped: false),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=8", isScrapped: false),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/500?random=9", isScrapped: false),
            ArchiveImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=10", isScrapped: false),
        ]
    }
    
    func toFeedImageItem() -> FeedImageItem {
        return FeedImageItem(id: id, imageURL: imageURL!, isScrapped: isScrapped)
    }
}
