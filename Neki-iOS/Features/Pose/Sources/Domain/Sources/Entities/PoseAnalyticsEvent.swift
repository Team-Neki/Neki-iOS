//
//  PoseAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/19/26.
//

import Foundation

enum PoseAnalyticsEvent {
    case randomPoseSuggestionStart
    case randomPoseSuggestionEnd(totalSwipeCount: Int)
    case poseFilterToggle(peopleCount: Int)
    case poseBookmarkFilter
    case poseBookmark
    /// 포즈 목록이나 북마크 목록에서 포즈 카드를 누른 순간 기록합니다. 상세 화면 안 좌우 넘기기와 랜덤 포즈는 제외합니다.
    case poseDetailClick(poseID: PoseID, peopleCount: Int, entryPoint: PoseEntryPoint)
}


// MARK: - PoseAnalyticsEvent + AnalyticsEvent

extension PoseAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .randomPoseSuggestionStart: return .poseRandomStart
        case .randomPoseSuggestionEnd: return .poseRandomSessionEnd
        case .poseFilterToggle: return .poseFilterToggle
        case .poseBookmarkFilter: return .poseBookmarkFilter
        case .poseBookmark: return .poseBookmark
        case .poseDetailClick: return .poseDetailClick
        }
    }
    
    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        switch self {
        case .randomPoseSuggestionStart, .poseBookmarkFilter, .poseBookmark: return nil
        case let .randomPoseSuggestionEnd(totalSwipeCount):
            return [.totalSwipeCount: .integer(totalSwipeCount)]
        case let .poseFilterToggle(peopleCount):
            return [.peopleCount: .integer(peopleCount)]
        case let .poseDetailClick(poseID, peopleCount, entryPoint):
            return [
                .poseId: .string(String(poseID)),
                .peopleCount: .integer(peopleCount),
                .entryPoint: .string(entryPoint.rawValue)
            ]
        }
    }
}


// MARK: - PoseAnalyticsEvent + Equatable

extension PoseAnalyticsEvent: Equatable {}
