//
//  FetchSearchFilterDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/4/26.
//

import Foundation

/// 고른 지역·역의 목록에서 쓸 수 있는 필터 조회
///
/// 요청 body가 부스 목록 조회와 완전히 같아 같은 타입을 그대로 씁니다.
/// 필터 집계는 거리를 쓰지 않아 서버가 `userLocation`을 무시하므로 담지 않고 보냅니다.
enum FetchSearchFilterDTO {
    typealias Request = FetchSearchResultPhotoBoothsDTO.Request

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
