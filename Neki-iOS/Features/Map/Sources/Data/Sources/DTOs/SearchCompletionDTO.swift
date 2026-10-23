//
//  SearchCompletionDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/7/26.
//

import Foundation

/// 지역·지하철역·포토부스 자동완성
///
/// 세 종류의 요청 파라미터와 응답 모양이 같아 한 타입으로 받습니다.
/// 탭 배지용 전체 건수(`totalCount`)는 쓰는 화면이 없어 받지 않습니다.
enum SearchCompletionDTO {
    struct Response: Decodable {
        let items: [Item]
        let hasNext: Bool
        /// 후보를 고른 뒤 부스 목록·필터 요청에 그대로 넘길 조회 조건입니다.
        ///
        /// 검색어로 정해지는 값이라 같은 응답의 후보가 모두 함께 씁니다.
        let filterGroup: SearchFilterGroupDTO

        /// 후보 페이지로 변환합니다. 응답의 조회 조건을 후보마다 담아 고른 후보만으로 부스 목록을 조회할 수 있게 합니다.
        func toEntity(type: PhotoBoothSearchCandidateType) -> PhotoBoothSearchCandidatePage {
            let filterGroup = filterGroup.toEntity()
            return PhotoBoothSearchCandidatePage(
                type: type,
                candidates: items.map { $0.toEntity(type: type, filterGroup: filterGroup) },
                hasNext: hasNext
            )
        }

        struct Item: Decodable {
            /// 화면에 그대로 표시하고, 고르면 부스 목록·필터 요청에 그대로 넘기는 값입니다.
            let keyword: String
            /// 요청에 담은 기준 위치로부터의 거리(km, 소수 첫째 자리)입니다.
            ///
            /// 역·부스 자동완성에 기준 위치를 담았을 때만 내려오고, 지역은 항상 `null`입니다.
            let distanceKm: Double?

            func toEntity(
                type: PhotoBoothSearchCandidateType,
                filterGroup: PhotoBoothSearchFilterGroup
            ) -> PhotoBoothSearchCandidate {
                PhotoBoothSearchCandidate(
                    type: type,
                    keyword: keyword,
                    filterGroup: filterGroup,
                    // 앱의 다른 거리와 같은 m 단위로 바꿉니다. 0.1km 단위라 반올림해 소수 오차를 없앱니다.
                    distance: distanceKm.map { GeographicDistance(meters: ($0 * 1000).rounded()) }
                )
            }
        }
    }
}
