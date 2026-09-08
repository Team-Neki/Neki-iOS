//
//  SearchPhotoBoothDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/31/26.
//

import Foundation

/// 통합 검색과 검색 결과 부스 조회가 공통으로 사용하는 포토부스 지점입니다.
///
/// 기존 지도 조회(`/photo-booths/polygon`, `/point`)와 달리 즐겨찾기 키가 `favorite`이고
/// 브랜드 코드가 함께 내려오므로 ``PhotoBoothDTO``와 분리했습니다.
struct SearchPhotoBoothDTO: Decodable {
    let id: Int
    let brandName: String
    /// 브랜드 전체 조회의 `code`와 같은 값입니다. 브랜드를 매칭하는 기준으로 사용합니다.
    let brandCode: String
    let branchName: String
    let address: String
    let latitude: Double
    let longitude: Double
    /// 사용자 현재 위치에서 부스까지의 거리(m).
    ///
    /// 부스 목록 요청에 `userLocation`을 담았을 때만 내려오고, 검색 응답에는 없습니다.
    let distance: Int?
    let favorite: Bool?

    func toEntity(brand: PhotoBoothBrand) -> PhotoBooth {
        PhotoBooth(
            id: id,
            brand: brand,
            name: branchName,
            coordinate: .init(latitude: latitude, longitude: longitude),
            address: address,
            nearbyDistance: distance,
            isFavorite: favorite ?? false
        )
    }
}

/// 부스 조회 API가 공통으로 받는 브랜드 필터입니다.
///
/// 비어 있으면 모든 브랜드를 조회합니다.
struct PhotoBoothBrandFilterDTO: Encodable {
    let brandIDs: [Int]

    enum CodingKeys: String, CodingKey {
        case brandIDs = "brandIds"
    }

    init(brandIDs: [Int] = []) {
        self.brandIDs = brandIDs
    }
}

/// 검색 결과 부스 조회의 공통 응답입니다. 지도에 한 번에 그리는 목록이라 페이징이 없습니다.
struct SearchPhotoBoothListDTO: Decodable {
    let photoBooths: [SearchPhotoBoothDTO]

    enum CodingKeys: String, CodingKey {
        case photoBooths = "items"
    }
}
