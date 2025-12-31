//
//  PhotoBooth.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

/// 포토부스 지점 정보
public struct PhotoBooth: Identifiable, Sendable {
    public let id: UUID
    public let brand: PhotoBoothBrand
    public let name: String
    public let coordinate: GeographicCoordinate
    public let address: String
    public let detailInformationURL: URL?
    
    public init(
        id: UUID,
        brand: PhotoBoothBrand,
        name: String,
        coordinate: GeographicCoordinate,
        address: String,
        detailInformationURL: URL? = nil
    ) {
        self.id = id
        self.brand = brand
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.detailInformationURL = detailInformationURL
    }
}
