//
//  FeedImageModel.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import Foundation

struct FeedImageItem: Equatable, Identifiable {
    let id: UUID
    let imageUrl: String
}

extension FeedImageItem {
    static func dummyData() -> [FeedImageItem] {
        return [
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(1)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(200)/\(500)?random=\(2)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(300)?random=\(3)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(800)?random=\(4)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(500)/\(500)?random=\(5)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(700)/\(500)?random=\(6)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(900)?random=\(7)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(100)?random=\(8)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(200)/\(500)?random=\(9)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(10)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(11)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(12)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(13)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(14)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(15)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(16)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(17)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(18)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(19)"),
            FeedImageItem(id: UUID(), imageUrl: "https://picsum.photos/\(300)/\(500)?random=\(20)")
        ]
    }
}
