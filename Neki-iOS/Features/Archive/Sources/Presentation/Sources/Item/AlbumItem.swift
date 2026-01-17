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
    let isFavorite: Bool
}
