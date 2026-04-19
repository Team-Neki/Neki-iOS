//
//  PoseAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/19/26.
//

import Foundation

enum PoseAnalyticsEvent {
    case poseView
    case randomPoseSuggestionStart
    case randomPoseSuggestionEnd(totalSwipeCount: Int)
    case poseFilterToggle(peopleCount: Int)
    case poseBookmarkFilter
    case poseBookmark
}


// MARK: - PoseAnalyticsEvent + AnalyticsEvent

extension PoseAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .poseView: return .poseView
        case .randomPoseSuggestionStart: return .poseRandomStart
        case .randomPoseSuggestionEnd: return .poseRandomSessionEnd
        case .poseFilterToggle: return .poseFilterToggle
        case .poseBookmarkFilter: return .poseBookmarkFilter
        case .poseBookmark: return .poseBookmark
        }
    }
    
    var parameters: [AnalyticsParameterKey : Any]? {
        switch self {
        case .poseView, .randomPoseSuggestionStart, .poseBookmarkFilter, .poseBookmark: return nil
        case let .randomPoseSuggestionEnd(totalSwipeCount):
            return [.totalSwipeCount: totalSwipeCount]
        case let .poseFilterToggle(peopleCount):
            return [.peopleCount: peopleCount]
        }
    }
}
