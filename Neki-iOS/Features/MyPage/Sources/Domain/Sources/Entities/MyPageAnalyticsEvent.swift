//
//  MyPageAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/20/26.
//

import Foundation

enum MyPageAnalyticsEvent {
    case logout
    case withdraw
}


// MARK: - MyPageAnalyticsEvent + AnalyticsEvent

extension MyPageAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .logout: return .logout
        case .withdraw: return .withdraw
        }
    }
    
    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? { return nil }
}
