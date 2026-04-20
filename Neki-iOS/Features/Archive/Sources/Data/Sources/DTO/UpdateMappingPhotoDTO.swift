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
        let photoIDs, targetFolderIDs: [Int]
        
        enum CodingKeys: String, CodingKey {
            case sourceFolderID = "sourceFolderId"
            case photoIDs = "photoIds"
            case targetFolderIDs = "targetFolderIds"
        }
    }
    
    public struct DuplicatePhotos: Encodable {
        let photoIDs, targetFolderIDs: [Int]

        enum CodingKeys: String, CodingKey {
            case photoIDs = "photoIds"
            case targetFolderIDs = "targetFolderIds"
        }
    }
}
