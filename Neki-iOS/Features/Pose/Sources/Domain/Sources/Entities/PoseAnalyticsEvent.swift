//
//  PoseAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/19/26.
//

import Foundation

enum PoseAnalyticsEvent {
    /// 포즈 첫 화면이 보일 때마다 기록합니다. 탭을 옮겨 오거나 포즈 상세·랜덤 포즈, QR·알림 목록에서 돌아올 때도 포함합니다.
    case poseView
    /// 랜덤 포즈 화면을 띄울 때 한 번 기록합니다. 첫 포즈를 불러오기 전에 보내므로 불러오기에 실패해도 남습니다.
    case randomPoseSuggestionStart
    /// 닫기 버튼이나 뒤로 스와이프로 랜덤 포즈 화면을 벗어날 때마다 한 번 기록합니다. totalSwipeCount는 요청에 성공해 실제로 넘어간 포즈 수입니다.
    /// 푸시 알림으로 이동하며 화면이 빠질 때는 사용자가 직접 끝낸 것이 아니므로 기록하지 않습니다.
    case randomPoseSuggestionEnd(totalSwipeCount: Int)
    case poseFilterToggle(peopleCount: Int)
    case poseBookmarkFilter
    /// 북마크 아이콘을 누를 때마다 기록합니다. 요청에 실패해도 남깁니다.
    case poseBookmark
    /// 포즈 목록이나 북마크 목록에서 포즈 카드를 누른 순간 기록합니다. 상세 화면 안 좌우 넘기기와 랜덤 포즈는 제외합니다.
    case poseDetailClick(poseID: PoseID, peopleCount: Int, entryPoint: PoseEntryPoint)
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
        case .poseDetailClick: return .poseDetailClick
        }
    }
    
    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        switch self {
        case .poseView, .randomPoseSuggestionStart, .poseBookmarkFilter, .poseBookmark: return nil
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
