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
        let brandIDs: [Int]
        
        init(longitude: Double, latitude: Double, radiusInMeters: Int, brandIDs: [Int] = []) {
            self.longitude = longitude
            self.latitude = latitude
            self.radiusInMeters = radiusInMeters
            self.brandIDs = brandIDs
        }
        
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
