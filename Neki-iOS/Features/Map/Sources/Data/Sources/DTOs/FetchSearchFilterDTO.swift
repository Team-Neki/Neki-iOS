//
//  FetchSearchFilterDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/4/26.
//

import Foundation

/// 고른 검색 후보의 목록에서 쓸 수 있는 필터 조회
///
/// 부스 목록 조회와 같은 `keyword`와 `filterGroup`을 보냅니다.
/// 정의되지 않은 필드를 담으면 `D-01`이라, 부스 목록 요청과 달리 `userLocation`을 담을 수 없도록 요청 타입을 따로 둡니다.
enum FetchSearchFilterDTO {
    struct Request: Encodable {
        /// 고른 후보의 `keyword`입니다. 가공하지 않고 그대로 보냅니다.
        let keyword: String
        /// 고른 후보가 속한 자동완성 응답의 조회 조건입니다. 조건이 없어도 `{}`로 담아야 합니다.
        let filterGroup: SearchFilterGroupDTO

        /// 고른 후보의 값을 그대로 담은 요청을 만듭니다.
        ///
        /// - Parameters:
        ///   - keyword: 고른 후보의 `keyword`
        ///   - filterGroup: 고른 후보가 속한 자동완성 응답의 조회 조건
        init(keyword: String, filterGroup: PhotoBoothSearchFilterGroup) {
            self.keyword = keyword
            self.filterGroup = SearchFilterGroupDTO(filterGroup)
        }
    }

    struct Response: Decodable {
        let brandFilters: [BrandFilter]

        enum CodingKeys: String, CodingKey {
            case brandFilters = "brandFilter"
        }

        /// 브랜드 이미지는 내려오지 않습니다. 브랜드 전체 조회에서 받은 값을 코드로 매칭해 채웁니다.
        struct BrandFilter: Decodable {
            let id: Int
            let name: String
            /// 브랜드 전체 조회의 `code`와 같은 값입니다. 브랜드를 매칭하는 기준으로 사용합니다.
            let code: String
            /// 그 범위 안에 있는 해당 브랜드의 부스 개수입니다.
            let count: Int
        }
    }
}
