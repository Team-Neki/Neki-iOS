//
//  PhotoListDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/24/26.
//

import Foundation

enum PhotoListDTO {
    struct Request: Encodable {
        let folderId: Int?
        let page: Int?
        let size: Int?
    }
    
    typealias Response = BaseResponseDTO<PhotoListData>
    
    struct PhotoListData: Decodable {
        let items: [PhotoListItem]
        let hasNext: Bool
    }
    
    struct PhotoListItem: Decodable {
        let photoID: Int
        let imageURL: String
        let folderID: Int
        let contentType, createdAt: String
        
        enum CodingKeys: String, CodingKey {
            case photoID = "photoId"
            case imageURL = "imageUrl"
            case folderID = "folderId"
            case contentType, createdAt
        }
    }
    
}

