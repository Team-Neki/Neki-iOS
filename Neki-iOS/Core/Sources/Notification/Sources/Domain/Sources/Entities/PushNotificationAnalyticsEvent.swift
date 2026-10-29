//
//  PushNotificationAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/16/26.
//

import Foundation

enum PushNotificationAnalyticsEvent {
    case notificationSent(
        notificationType: String,
        targetType: String,
        messageTone: String,
        hasVariable: Bool
    )
    /// 푸시 알림을 눌러 앱을 열 때 기록합니다. Android와 같이 속성 없이 보냅니다.
    case notificationClick
}

extension PushNotificationAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .notificationSent:
            return .notificationSent
        case .notificationClick:
            return .notificationClick
        }
    }

    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        switch self {
        case let .notificationSent(notificationType, targetType, messageTone, hasVariable):
            return [
                .notificationType: .string(notificationType),
                .targetType: .string(targetType),
                .messageTone: .string(messageTone),
                .hasVariable: .boolean(hasVariable)
            ]
        case .notificationClick:
            return nil
        }
    }
}
