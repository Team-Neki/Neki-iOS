//
//  PhotoListDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/24/26.
//

import Foundation

public enum PhotoListDTO {
    public struct Request: Encodable {
        let folderId: Int?
        let page: Int?
        let size: Int?
        let sortOrder: String? // ASC, DESC
    }
    
    public typealias Response = PhotoListData
    
    public struct PhotoListData: Decodable {
        let items: [PhotoListItem]
        let hasNext: Bool
        
        func toEntity() -> [PhotoEntity] {
            return items.map {
                PhotoEntity(
                    photoID: $0.photoID,
                    imageURL: $0.imageURL,
                    folderID: $0.folderID,
                    isfavorite: $0.favorite,
                    contentType: $0.contentType,
                    createdAt: $0.createdAt,
                    memo: $0.memo,
                    width: $0.width,
                    height: $0.height
                )
            }
        }
    }
    
    public struct PhotoListItem: Decodable {
        let photoID: Int
        let imageURL: String
        let folderID: Int?
        let favorite: Bool
        let contentType, createdAt: String
        let memo: String?
        let width, height: Int?
        
        enum CodingKeys: String, CodingKey {
            case photoID = "photoId"
            case imageURL = "imageUrl"
            case folderID = "folderId"
            case favorite = "favorite"
            case contentType, createdAt, memo, width, height
        }
    }
    
}

