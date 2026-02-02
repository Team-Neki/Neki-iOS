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
    let imageURL: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case brandName = "name"
        case brandNameEnglish = "code"
        case imageURL = "imageUrl"
    }
    
    func toEntity() -> PhotoBoothBrand? {
        switch brandName {
        case "플랜비 스튜디오": return .planBStudio
        case "하루필름": return .harufilm
        case "포토시그니처": return .photosignature
        case "포토그레이": return .photogray
        case "인생네컷": return .life4cut
        case "포토이즘": return .photoism
        default: return nil
        }
    }
}
