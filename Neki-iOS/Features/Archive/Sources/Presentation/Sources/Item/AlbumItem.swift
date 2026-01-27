//
//  AlbumItem.swift
//  Neki-iOS
//
//  Created by OneTen on 1/17/26.
//

import Foundation

struct AlbumItem: Equatable, Identifiable {
    let id: Int
    let title: String
    let count: Int
    let coverImageURL: URL?
    let isFavorite: Bool    // 서버에서 내려줄지 안내려줄지 아직 모름
}
