//
//  FetchPhotoBoothsDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation

/// 지도 영역 내 포토부스 조회
enum FetchPhotoBoothsDTO {
    struct Request: Encodable {
        /// 좌상단부터 시계방향으로 5개의 꼭짓점으로 표현된 영역
        let coordinates: [GeographicCoordinate]
        let brandIDs: [Int] = []
        
        enum CodingKeys: String, CodingKey {
            case coordinates
            case brandIDs = "brandIds"
        }
        
        init(bounds: GeographicBoundingBox) {
            let topLeft = GeographicCoordinate(latitude: bounds.maxLatitude, longitude: bounds.minLongitude)
            let topRight = GeographicCoordinate(latitude: bounds.maxLatitude, longitude: bounds.maxLongitude)
            let bottomRight = GeographicCoordinate(latitude: bounds.minLatitude, longitude: bounds.maxLongitude)
            let bottomLeft = GeographicCoordinate(latitude: bounds.minLatitude, longitude: bounds.minLongitude)
            self.coordinates = [topLeft, topRight, bottomRight, bottomLeft, topLeft]
        }
    }
    
    struct Response: Decodable {
        let photoBooths: [PhotoBoothDTO]
        
        enum CodingKeys: String, CodingKey {
            case photoBooths = "items"
        }
    }
}

