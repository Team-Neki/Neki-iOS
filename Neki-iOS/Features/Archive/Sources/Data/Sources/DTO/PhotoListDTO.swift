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
        let totalCount: Int
        
        func toEntity() -> [PhotoEntity] {
            items.map {
                PhotoEntity(
                    id: $0.photoID,
                    imageURL: URL(string: $0.imageURL),
                    isFavorite: $0.favorite,
                    createdAt: $0.createdAt.toISO8601DateOrNil() ?? Date(),
                    folderID: $0.folderID,
                    memo: $0.memo ?? "",
                    width: $0.width,
                    height: $0.height,
                    contentType: $0.contentType,
                    createdAtRawValue: $0.createdAt
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
