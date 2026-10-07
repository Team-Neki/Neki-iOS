//
//  PhotoBoothSearchCandidate.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation

/// 지도 검색에서 사용자가 선택할 수 있는 검색 후보입니다.
///
/// 세 종류 모두 자동완성 응답의 `keyword`와 `filterGroup`만으로 부스 목록을 조회하므로 한 타입으로 표현합니다.
/// 두 값은 서버가 정한 값이라 가공하지 않고 조회에 그대로 넘기며, `keyword`는 화면에도 그대로 표시합니다.
public struct PhotoBoothSearchCandidate: Equatable, Sendable, Identifiable {
    public let type: PhotoBoothSearchCandidateType
    /// 목록에 그대로 표시하고, 고르면 부스 목록·필터 조회에 그대로 넘기는 이름입니다.
    ///
    /// 서버가 지역은 `서울특별시 강남구`, 지하철역은 `강남역 2호선`, 포토부스는 `포토이즘 강남1호점`처럼 조합해 내려줍니다.
    public let keyword: String
    /// 고른 뒤 부스 목록·필터 조회에 그대로 넘길 조회 조건입니다. 후보가 속한 종류의 응답이 내려준 값입니다.
    public let filterGroup: PhotoBoothSearchFilterGroup
    /// 검색 기준 위치로부터의 거리입니다.
    ///
    /// 지역은 거리를 내려주지 않고, 지하철역과 포토부스도 기준 위치를 넘기지 않으면 `nil`입니다.
    public let distance: GeographicDistance?

    /// 목록에서 후보를 구분하는 식별자입니다.
    ///
    /// 서버가 후보를 `keyword`로만 구분해 내려주므로 종류와 `keyword`를 함께 씁니다.
    public var id: String { "\(type):\(keyword)" }

    /// 검색 후보를 생성합니다.
    ///
    /// - Parameters:
    ///   - type: 후보의 종류
    ///   - keyword: 서버가 조합해 내려준 이름
    ///   - filterGroup: 후보가 속한 응답의 조회 조건
    ///   - distance: 검색 기준 위치로부터의 거리. 내려오지 않았으면 `nil`
    public init(
        type: PhotoBoothSearchCandidateType,
        keyword: String,
        filterGroup: PhotoBoothSearchFilterGroup,
        distance: GeographicDistance? = nil
    ) {
        self.type = type
        self.keyword = keyword
        self.filterGroup = filterGroup
        self.distance = distance
    }
}

/// 검색어 기반 검색 후보 종류입니다.
public enum PhotoBoothSearchCandidateType: Equatable, Sendable, CaseIterable {
    case region         // 지역구
    case subwayStation  // 지하철역
    case photoBooth     // 포토부스

    /// 검색 결과 목록에서의 노출 순서입니다. 값이 작을수록 앞에 노출합니다.
    ///
    /// 지역 → 지하철역 → 포토부스 순서로 노출하는 검색 정책을 표현합니다.
    public var displayOrder: Int {
        switch self {
        case .region: 0
        case .subwayStation: 1
        case .photoBooth: 2
        }
    }

    /// 정책 순서로 정렬한 전체 종류입니다.
    public static var displayOrdered: [Self] {
        allCases.sorted { $0.displayOrder < $1.displayOrder }
    }
}
