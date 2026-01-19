//
//  AlbumItem.swift
//  Neki-iOS
//
//  Created by OneTen on 1/17/26.
//

import Foundation

struct AlbumItem: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let coverImageURL: URL?
    let isFavorite: Bool    // 서버에서 내려줄지 안내려줄지 아직 모름
}

extension AlbumItem {
    static func dummyData() -> [AlbumItem] {
        return [
            AlbumItem(title: "즐겨찾는 사진", count: 12, coverImageURL: URL(string: "https://picsum.photos/200/300?random=1"), isFavorite: true),
            AlbumItem(title: "앨범 제목123123", count: 15, coverImageURL: URL(string: "https://picsum.photos/200/300?random=2"), isFavorite: false),
            AlbumItem(title: "앨범 제목", count: 8, coverImageURL: URL(string: "https://picsum.photos/200/300?random=3"), isFavorite: false)
        ]
    }
}
