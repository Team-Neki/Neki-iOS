//
//  PhotoBoothSearchFilterGroup.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/7/26.
//

import Foundation

/// 자동완성 응답이 검색어를 읽어 함께 내려주는 조회 조건입니다.
///
/// 후보를 고른 뒤 부스 목록·필터 조회에 가공하지 않고 그대로 넘깁니다.
/// 검색어에 브랜드명 전체가 들어 있으면(`강남 포토이즘`) 그 브랜드가 걸려 있고, 없으면 조건이 비어 있습니다.
public struct PhotoBoothSearchFilterGroup: Equatable, Sendable {
    /// 조회할 브랜드입니다. `nil`이거나 비어 있으면 모든 브랜드를 조회합니다.
    public let brandIDs: [PhotoBoothBrand.ID]?
    /// 정렬 방식입니다. `nil`이면 서버의 기본 정렬을 따르며, 지금은 기본 정렬(`DEFAULT`)만 있습니다.
    public let sortType: String?

    /// 조회 조건을 생성합니다. 아무 값도 주지 않으면 조건이 없는 상태입니다.
    ///
    /// - Parameters:
    ///   - brandIDs: 조회할 브랜드. `nil`이거나 비어 있으면 모든 브랜드
    ///   - sortType: 서버가 내려준 정렬 방식
    public init(brandIDs: [PhotoBoothBrand.ID]? = nil, sortType: String? = nil) {
        self.brandIDs = brandIDs
        self.sortType = sortType
    }
}
