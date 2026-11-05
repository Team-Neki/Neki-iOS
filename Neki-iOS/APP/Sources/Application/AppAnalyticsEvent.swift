//
//  AppAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/29/26.
//

import Foundation

enum AppAnalyticsEvent {
    /// 앱을 실행해 자동 로그인에 성공했을 때 한 번 기록합니다. 로그인 화면에서 새로 로그인한 경우는 기록하지 않습니다.
    case appOpen
}


// MARK: - AppAnalyticsEvent + AnalyticsEvent

extension AppAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .appOpen: return .appOpen
        }
    }
    
    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? { return nil }
}
