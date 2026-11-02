//
//  PushNotificationAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/16/26.
//

import Foundation

enum PushNotificationAnalyticsEvent {
    /// 푸시 알림을 눌러 앱을 열 때 기록합니다. Android와 같이 속성 없이 보냅니다.
    case notificationClick
}

extension PushNotificationAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .notificationClick:
            return .notificationClick
        }
    }

    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        switch self {
        case .notificationClick:
            return nil
        }
    }
}
