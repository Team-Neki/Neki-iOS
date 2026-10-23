//
//  PhotoBoothMarkerPresentationState.swift
//  Neki-iOS
//
//  Created by Codex on 10/17/26.
//

import Foundation

/// 지도 마커 표현에 실제로 영향을 주는 POI 값만 보관합니다.
struct PhotoBoothMarkerPresentationState: Equatable {
    let id: PhotoBooth.ID
    let coordinate: GeographicCoordinate
    let brandID: PhotoBoothBrand.ID
    let brandName: String
    let brandImageURL: URL?
    let name: String
    let isFavorite: Bool

    init(booth: PhotoBooth) {
        id = booth.id
        coordinate = booth.coordinate
        brandID = booth.brand.id
        brandName = booth.brand.name
        brandImageURL = booth.brand.imageURL
        name = booth.name
        isFavorite = booth.isFavorite
    }
}
