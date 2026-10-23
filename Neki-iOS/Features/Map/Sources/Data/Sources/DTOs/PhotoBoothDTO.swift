//
//  PhotoBoothDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation

struct PhotoBoothDTO: Decodable {
    let id: String
    let brandName: String
    let branchName: String
    let address: String
    let longitude: Double
    let latitude: Double
    let nearbyDistance: Int?
    /// 즐겨찾기 목록 응답에는 이 값이 없어 선택값으로 받습니다.
    let isFavorite: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, address, longitude, latitude, brandName, branchName
        case nearbyDistance = "distance"
        case isFavorite = "favorite"
    }
    
    func toEntity(brand: PhotoBoothBrand) -> PhotoBooth {
        PhotoBooth(
            id: id,
            brand: brand,
            name: branchName,
            coordinate: .init(latitude: latitude, longitude: longitude),
            address: address,
            nearbyDistance: nearbyDistance.map(GeographicDistance.init),
            isFavorite: isFavorite ?? false
        )
    }
}
