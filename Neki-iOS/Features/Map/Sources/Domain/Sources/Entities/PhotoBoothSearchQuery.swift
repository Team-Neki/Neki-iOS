//
//  PhotoBoothSearchQuery.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation

/// 사용자가 제출한 검색어입니다.
///
/// 서버 검색은 접두 일치이므로 입력한 값을 다듬지 않고 그대로 담습니다.
/// 공백뿐인 검색어를 거절할지는 서버가 판정하므로 클라이언트에서 미리 걸러내지 않습니다.
public struct PhotoBoothSearchQuery: RawRepresentable, Equatable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
