//
//  PhotoBoothDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation

struct PhotoBoothDTO: Decodable {
    let id: Int
    let brandName: String
    let branchName: String
    let address: String
    let longitude: Double
    let latitude: Double
    let nearbyDistance: Int?
    let isFavorite: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, address, longitude, latitude, brandName, branchName, isFavorite
        case nearbyDistance = "distance"
    }
    
    func toEntity(brand: PhotoBoothBrand) -> PhotoBooth {
        PhotoBooth(
            id: id,
            brand: brand,
            name: branchName,
            coordinate: .init(latitude: latitude, longitude: longitude),
            address: address,
            nearbyDistance: nearbyDistance,
            isFavorite: isFavorite ?? false
        )
    }
}
