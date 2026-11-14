//
//  PoseRelation.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/11/26.
//

import Foundation

/// 2인 포즈에 붙는 관계 태그입니다. 태그 바의 칩 순서대로 선언합니다.
///
/// 서버 값은 `FRIEND`·`COUPLE`·`SSUM`입니다. 요청은 `DefaultPoseRepository`, 응답은 `PoseDTO`에서 바꿉니다.
public enum PoseRelation: CaseIterable, Hashable, Sendable {
    case friend
    case couple
    /// 썸입니다. `some`으로 지으면 `Optional.some`과 겹쳐 `== .some` 비교가 옵셔널 쪽으로 풀립니다.
    case crush
    
    var displayName: String {
        switch self {
        case .friend: "친구"
        case .couple: "커플"
        case .crush: "썸"
        }
    }
}
