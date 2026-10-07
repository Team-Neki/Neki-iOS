//
//  SearchFilterGroupDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/7/26.
//

import Foundation

/// 자동완성 응답이 내려주고, 부스 목록·필터 요청이 그대로 돌려받는 조회 조건입니다.
///
/// 검색어에 브랜드명 전체가 들어 있으면(`강남 포토이즘`) 그 브랜드가 걸려 내려옵니다.
/// 서버가 검색어를 읽어 정한 값이라 클라이언트는 가공하지 않고 받은 모양 그대로 다시 보냅니다.
///
/// 조건이 없어도 요청에서 이 필드를 빼면 `D-01`이므로 `{}`로라도 담아 보내야 합니다.
struct SearchFilterGroupDTO: Codable {
    /// `nil`이면 키째 빠지고, 서버는 모든 브랜드를 조회합니다.
    let brandFilter: BrandFilter?
    /// `nil`이면 키째 빠지고, 서버는 기본 정렬로 조회합니다.
    let sortFilter: SortFilter?

    struct BrandFilter: Codable {
        /// 조회할 브랜드입니다. `null`이거나 비어 있으면 모든 브랜드를 조회합니다.
        let brands: [Brand]?
    }

    struct Brand: Codable {
        let brandID: Int

        enum CodingKeys: String, CodingKey {
            case brandID = "brandId"
        }
    }

    struct SortFilter: Codable {
        /// 정렬 방식입니다. 지금은 `DEFAULT`만 있습니다.
        let type: String
    }
}


// MARK: - SearchFilterGroupDTO + Entity

extension SearchFilterGroupDTO {
    /// 고른 후보의 조회 조건을 요청에 담을 모양으로 되돌립니다.
    ///
    /// 받을 때 없던 조건은 키째 빼므로, 조건이 하나도 없으면 `{}`로 보냅니다.
    init(_ filterGroup: PhotoBoothSearchFilterGroup) {
        self.init(
            brandFilter: filterGroup.brandIDs.map { BrandFilter(brands: $0.map(Brand.init(brandID:))) },
            sortFilter: filterGroup.sortType.map(SortFilter.init(type:))
        )
    }

    func toEntity() -> PhotoBoothSearchFilterGroup {
        PhotoBoothSearchFilterGroup(
            brandIDs: brandFilter?.brands?.map(\.brandID),
            sortType: sortFilter?.type
        )
    }
}
