//
//  FetchSearchResultPhotoBoothsDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/31/26.
//

import Foundation

/// 고른 지역·역의 부스 목록 조회
///
/// 목록과 필터 칩이 같은 요청 body를 쓰므로, 필터를 붙일 때 이 요청을 그대로 재사용합니다.
enum FetchSearchResultPhotoBoothsDTO {
    struct Request: Encodable {
        /// 지역을 고른 경우에만 채웁니다.
        let regionFilter: RegionFilter?
        /// 지하철역을 고른 경우에만 채웁니다.
        let stationFilter: StationFilter?
        let brandFilter: PhotoBoothBrandFilterDTO
        /// 거리 계산의 기준이 되는 사용자 현재 위치입니다.
        ///
        /// 주지 않으면 응답의 `distance`가 `null`이고 정렬이 브랜드, 지점 이름 순으로 바뀝니다.
        let userLocation: GeographicCoordinate?

        struct RegionFilter: Encodable {
            /// 지역 검색 응답의 법정동코드
            let code: String
        }

        struct StationFilter: Encodable {
            /// 지하철역 검색 응답의 역명
            let name: String
            /// 지하철역 검색 응답의 노선명
            let lineName: String
        }

        /// 고른 대상에 해당하는 필터만 채운 요청을 만듭니다.
        ///
        /// - Parameters:
        ///   - target: 사용자가 고른 지역 또는 지하철역
        ///   - userCoordinate: 사용자 현재 위치. 위치를 알 수 없으면 `nil`을 전달합니다.
        ///   - brandIDs: 조회할 브랜드. 비어 있으면 모든 브랜드입니다.
        init(
            target: PhotoBoothSearchTarget,
            userCoordinate: GeographicCoordinate?,
            brandIDs: [Int] = []
        ) {
            switch target {
            case let .region(code):
                self.regionFilter = RegionFilter(code: code)
                self.stationFilter = nil

            case let .subwayStation(name, lineName):
                self.regionFilter = nil
                self.stationFilter = StationFilter(name: name, lineName: lineName)
            }
            self.brandFilter = PhotoBoothBrandFilterDTO(brandIDs: brandIDs)
            self.userLocation = userCoordinate
        }
    }

    typealias Response = SearchPhotoBoothListDTO
}
