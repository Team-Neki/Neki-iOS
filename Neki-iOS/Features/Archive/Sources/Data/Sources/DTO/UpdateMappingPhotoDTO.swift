//
//  UpdateMappingPhotoDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 4/12/26.
//

import Foundation

public enum UpdateMappingPhotoDTO {
    public struct MovePhotos: Encodable {
        let sourceFolderID: Int
        let photoIDS, targetFolderIDS: [Int]
        
        enum CodingKeys: String, CodingKey {
            case sourceFolderID = "sourceFolderId"
            case photoIDS = "photoIds"
            case targetFolderIDS = "targetFolderIds"
        }
    }
    
    public struct DuplicatePhotos: Encodable {
        let photoIDS, targetFolderIDS: [Int]

        enum CodingKeys: String, CodingKey {
            case photoIDS = "photoIds"
            case targetFolderIDS = "targetFolderIds"
        }
    }
}
