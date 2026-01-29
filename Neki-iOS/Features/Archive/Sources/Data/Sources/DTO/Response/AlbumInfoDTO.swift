//
//  AlbumInfoDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/27/26.
//

import Foundation

public struct AlbumInfoDTO: Codable {
    let items: [AlbumInfoData]
}

public struct AlbumInfoData: Codable {
    let folderID: Int
    let name: String
    let latestImageURL: String?
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case folderID = "folderId"
        case name
        case latestImageURL = "latestImageUrl"
        case totalCount
    }
}
