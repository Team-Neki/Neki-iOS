//
//  PhotoBoothSearchPage.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation

/// 동일한 종류의 검색 후보를 서버 순서대로 제공하는 페이지입니다.
public struct PhotoBoothSearchCandidatePage: Equatable, Sendable {
    public let type: PhotoBoothSearchCandidateType
    public let candidates: [PhotoBoothSearchCandidate]
    public let hasNext: Bool

    /// 검색 후보 페이지를 생성합니다.
    ///
    /// - Parameters:
    ///   - type: 페이지에 포함된 후보의 종류
    ///   - candidates: 서버 순서를 유지한 검색 후보
    ///   - hasNext: 다음 후보 페이지의 존재 여부
    public init(
        type: PhotoBoothSearchCandidateType,
        candidates: [PhotoBoothSearchCandidate],
        hasNext: Bool
    ) {
        self.type = type
        self.candidates = candidates
        self.hasNext = hasNext
    }
}

/// 검색 목록의 페이징 규격입니다.
///
/// 부스 조회에는 페이징이 없으므로 검색 후보 목록에만 적용합니다.
public enum PhotoBoothSearchPaging {
    /// 첫 페이지 번호입니다.
    public static let firstPage: Int = 0
    /// 한 번에 요청할 후보 수입니다. 서버가 허용하는 범위는 1~100입니다.
    public static let size: Int = 20
}
