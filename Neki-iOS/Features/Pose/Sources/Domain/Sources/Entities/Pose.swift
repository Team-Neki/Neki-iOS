//
//  Pose.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

public struct Pose: Identifiable, Sendable, Equatable {
    public let id: Int
    public let peopleCountOption: PeopleCountOption
    public let imageURL: URL?
    public var isScrapped: Bool
    public let contentType: ImageContentType
    public let width: Int?
    public let height: Int?
    /// 2인 포즈의 관계입니다. 관계가 없는 포즈는 nil입니다.
    public var relation: PoseRelation? = nil
}
