//
//  PhotoBooth.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

/// 포토부스 지점 정보
public struct PhotoBooth: Identifiable, Sendable, Equatable, Hashable {
    public let id: Int
    public let brand: PhotoBoothBrand
    public let name: String
    public let coordinate: GeographicCoordinate
    public let address: String
    public let nearbyDistance: Int?
    public let detailInformationURL: URL?
    public var isFavorite: Bool
    
    public init(
        id: Int,
        brand: PhotoBoothBrand,
        name: String,
        coordinate: GeographicCoordinate,
        address: String,
        nearbyDistance: Int? = nil,
        detailInformationURL: URL? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.brand = brand
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.nearbyDistance = nearbyDistance
        self.detailInformationURL = detailInformationURL
        self.isFavorite = isFavorite
    }
}
