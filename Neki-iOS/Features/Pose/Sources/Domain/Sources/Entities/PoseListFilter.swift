//
//  PoseListFilter.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/16/26.
//

import Foundation

/// 포즈 목록을 서버에서 거르는 조건입니다. 비어 있으면 전체 목록입니다.
public struct PoseListFilter: Hashable, Sendable {
    public var peopleCount: PeopleCountOption?
    /// 관계는 2인 포즈에만 있어서, 2인이 아닌 인원수와 함께 보내면 서버가 빈 목록을 돌려줍니다.
    public var relation: PoseRelation?
    
    /// 이 조건에 맞는 포즈인지 봅니다. 조건을 바꾼 뒤 새 첫 페이지가 오기 전까지 이미 불러온 목록을 거를 때 씁니다.
    func matches(_ pose: Pose) -> Bool {
        if let peopleCount, pose.peopleCountOption != peopleCount { return false }
        if let relation, pose.relation != relation { return false }
        return true
    }
}
