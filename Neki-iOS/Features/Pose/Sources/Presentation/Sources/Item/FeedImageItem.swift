//
//  FeedImageItem.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import Foundation

struct FeedImageItem: Equatable, Identifiable {
    let id: UUID
    let imageURL: URL?
    var isScrapped: Bool
    
    init(id: UUID, imageURLString: String, isScrapped: Bool = false) {
        self.id = id
        self.imageURL = URL(string: imageURLString)
        self.isScrapped = isScrapped
    }
    
    init(id: UUID, imageURL: URL, isScrapped: Bool = false) {
        self.id = id
        self.imageURL = imageURL
        self.isScrapped = isScrapped
    }
}

extension FeedImageItem {
    static func dummyData() -> [FeedImageItem] {
        return [
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=1", isScrapped: true),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/500?random=2", isScrapped: false),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/300/300?random=3", isScrapped: false),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/500/300?random=4", isScrapped: true),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/500?random=5", isScrapped: false),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=6", isScrapped: false),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/700/300?random=7", isScrapped: false),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=8", isScrapped: false),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/500?random=9", isScrapped: false),
            FeedImageItem(id: UUID(), imageURLString: "https://picsum.photos/200/300?random=10", isScrapped: false),
        ]
    }
}
