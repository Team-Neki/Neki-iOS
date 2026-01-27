//
//  FetchNearbyPhotoBoothsDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation

/// 특정 좌표 기준 반경 내 포토부스 조회
enum FetchNearbyPhotoBoothsDTO {
    struct Request: Encodable {
        let longitude: Double
        let latitude: Double
        let radiusInMeters: Int
        let brandIDs: [Int] = []
        
        enum CodingKeys: String, CodingKey {
            case longitude, latitude, radiusInMeters
            case brandIDs = "brandIds"
        }
    }
    
    struct Response: Decodable {
        let photoBooths: [PhotoBoothDTO]
        
        enum CodingKeys: String, CodingKey {
            case photoBooths = "items"
        }
    }
}
