//
//  PhotoBoothSearchCandidate.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation

/// 지도 검색에서 사용자가 선택할 수 있는 검색 후보입니다.
///
/// API 식별자 규격이 확정되지 않았으므로 전송 규격에 해당하는 식별자는 포함하지 않습니다.
/// 서버 식별자는 API 계약이 확정된 뒤 Data 계층에서 Domain 타입으로 변환합니다.
public struct PhotoBoothSearchCandidate: Equatable, Sendable {
    public let type: PhotoBoothSearchCandidateType
    public let name: String

    /// 검색 후보를 생성합니다.
    ///
    /// - Parameters:
    ///   - type: 검색 후보의 의미를 구분하는 종류
    ///   - name: 사용자에게 표시할 서버 원문 이름
    public init(type: PhotoBoothSearchCandidateType, name: String) {
        self.type = type
        self.name = name
    }
}

/// 검색어 기반 검색 후보 종류입니다.
public enum PhotoBoothSearchCandidateType: Equatable, Sendable {
    case region         // 지역구
    case subwayStation  // 지하철역
    case photoBooth     // 포토부스
}
