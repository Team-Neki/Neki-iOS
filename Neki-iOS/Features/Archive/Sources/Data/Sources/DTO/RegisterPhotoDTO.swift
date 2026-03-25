//
//  RegisterPhotoDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/26/26.
//

import Foundation

public enum RegisterPhotoDTO {
    public struct Request: Encodable {
        let folderID: Int?
        let uploads: [RegisterPhotoData]
        let favorite: Bool?

        enum CodingKeys: String, CodingKey {
            case folderID = "folderId"
            case uploads, favorite
        }
    }
    
    public struct RegisterPhotoData: Encodable {
        let mediaID: Int
        let memo: String?
        let uploadMethod: String

        enum CodingKeys: String, CodingKey {
            case mediaID = "mediaId"
            case memo
            case uploadMethod
        }
    }

}
