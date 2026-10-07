//
//  FetchSearchResultPhotoBoothsDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/31/26.
//

import Foundation

/// 고른 검색 후보의 부스 목록 조회
///
/// 필터 칩도 같은 `keyword`와 `filterGroup`으로 조회하지만, 필터 요청은 `userLocation`을 받지 않아 요청 타입을 따로 둡니다.
enum FetchSearchResultPhotoBoothsDTO {
    struct Request: Encodable {
        /// 고른 후보의 `keyword`입니다. 가공하지 않고 그대로 보냅니다.
        let keyword: String
        /// 고른 후보가 속한 자동완성 응답의 조회 조건입니다. 조건이 없어도 `{}`로 담아야 합니다.
        let filterGroup: SearchFilterGroupDTO
        /// 거리 계산의 기준이 되는 사용자 현재 위치입니다.
        ///
        /// 주지 않으면 키째 빠지고, 응답의 `distance`가 `null`이며 정렬이 브랜드, 지점 이름 순으로 바뀝니다.
        let userLocation: GeographicCoordinate?

        /// 고른 후보의 값을 그대로 담은 요청을 만듭니다.
        ///
        /// - Parameters:
        ///   - keyword: 고른 후보의 `keyword`
        ///   - filterGroup: 고른 후보가 속한 자동완성 응답의 조회 조건
        ///   - userCoordinate: 사용자 현재 위치. 위치를 알 수 없으면 `nil`을 전달합니다.
        init(
            keyword: String,
            filterGroup: PhotoBoothSearchFilterGroup,
            userCoordinate: GeographicCoordinate?
        ) {
            self.keyword = keyword
            self.filterGroup = SearchFilterGroupDTO(filterGroup)
            self.userLocation = userCoordinate
        }
    }

    typealias Response = SearchPhotoBoothListDTO
}
