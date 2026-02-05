//
//  PhotoBoothBrandDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation

struct PhotoBoothBrandDTO: Decodable {
    let id: Int
    let brandName: String
    let brandNameEnglish: String
    let imageURLString: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case brandName = "name"
        case brandNameEnglish = "code"
        case imageURLString = "imageUrl"
    }
    
    func toEntity() -> PhotoBoothBrand {
        .init(id: id, name: brandName, englishName: brandNameEnglish, imageURL: URL(string: imageURLString))
    }
}
