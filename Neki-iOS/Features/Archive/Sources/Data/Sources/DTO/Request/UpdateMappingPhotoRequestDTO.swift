//
//  UpdateMappingPhotoRequestDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 4/12/26.
//

import Foundation

public struct UpdateMappingPhotoRequestDTO: Codable {
    let sourceFolderID: Int?
    let photoIDS, targetFolderIDS: [Int]

    enum CodingKeys: String, CodingKey {
        case sourceFolderID = "sourceFolderId"
        case photoIDS = "photoIds"
        case targetFolderIDS = "targetFolderIds"
    }
}
