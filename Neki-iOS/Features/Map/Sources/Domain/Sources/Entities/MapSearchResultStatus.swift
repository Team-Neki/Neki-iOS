//
//  MapSearchResultStatus.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/25/26.
//

import Foundation

/// 정상적으로 완료된 검색 후보 조회의 결과 여부입니다. 기술적 실패는 포함하지 않습니다.
enum MapSearchResultStatus: String, Sendable {
    case matched = "matched"
    case unmatched = "unmatched"
}
