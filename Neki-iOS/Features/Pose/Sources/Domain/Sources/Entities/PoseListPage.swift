//
//  PoseListPage.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/16/26.
//

import Foundation

/// 포즈 목록 한 페이지입니다.
public struct PoseListPage: Equatable, Sendable {
    public let poses: [Pose]
    public let hasNext: Bool
    /// 조건에 맞는 전체 포즈 수입니다. 응답에 없으면 nil이고, 화면은 개수만 숨깁니다.
    public let totalCount: Int?
}
