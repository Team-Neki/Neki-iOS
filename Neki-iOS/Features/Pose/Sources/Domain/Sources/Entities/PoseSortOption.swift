//
//  PoseSortOption.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/11/26.
//

import Foundation

/// 포즈 목록의 정렬 기준입니다. 정렬 메뉴의 순서대로 선언합니다.
///
/// 8-1은 최신순 고정이라 메뉴를 끄고 최신순만 보여 줍니다(`PoseFeature.State.isSortMenuEnabled`). 서버 정렬은 인기순을 도입할 때 연결합니다.
public enum PoseSortOption: CaseIterable, Hashable, Sendable {
    case popular
    case latest
    case recommended
    
    var displayName: String {
        switch self {
        case .popular: "인기순"
        case .latest: "최신순"
        case .recommended: "추천순"
        }
    }
}
