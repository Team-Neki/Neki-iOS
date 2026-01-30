//
//  FavoriteAlbumInfoDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/27/26.
//

import Foundation

public struct FavoriteAlbumInfoDTO: Decodable {
    let latestImageURL: String?
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case latestImageURL = "latestImageUrl"
        case totalCount
    }
}
