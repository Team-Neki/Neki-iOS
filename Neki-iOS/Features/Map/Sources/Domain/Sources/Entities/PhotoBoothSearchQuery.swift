//
//  PhotoBoothSearchQuery.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation

/// 사용자가 제출한 검색어 원문입니다.
///
/// 클라이언트에서 정규화하거나 유효성을 판정하지 않고 입력값을 그대로 보존합니다.
public struct PhotoBoothSearchQuery: RawRepresentable, Equatable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
