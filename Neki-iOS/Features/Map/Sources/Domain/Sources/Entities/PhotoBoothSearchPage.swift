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

/// 검색 세션에서 서버 순서대로 누적할 POI 페이지입니다.
public struct PhotoBoothSearchResultPage: Equatable, Sendable {
    public let photoBooths: [PhotoBooth]
    public let hasNext: Bool

    /// POI 검색 결과 페이지를 생성합니다.
    ///
    /// - Parameters:
    ///   - photoBooths: 서버 순서를 유지한 포토부스 지점
    ///   - hasNext: 다음 POI 페이지의 존재 여부
    public init(photoBooths: [PhotoBooth], hasNext: Bool) {
        self.photoBooths = photoBooths
        self.hasNext = hasNext
    }
}
