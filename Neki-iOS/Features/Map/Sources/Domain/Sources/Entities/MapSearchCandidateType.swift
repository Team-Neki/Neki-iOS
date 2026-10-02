//
//  MapSearchCandidateType.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/25/26.
//

import Foundation

/// 분석 계약에서 사용하는 후보 유형입니다. 서버나 검색 도메인의 식별자와 구분합니다.
enum MapSearchCandidateType: String, Sendable {
    case district = "district"
    case subwayStation = "subway_station"
    case booth = "booth"
}
