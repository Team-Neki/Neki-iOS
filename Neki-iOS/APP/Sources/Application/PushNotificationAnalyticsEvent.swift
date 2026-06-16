//
//  PushNotificationAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import Foundation

enum PushNotificationAnalyticsEvent {
    case notificationClick(payload: PushNotificationPayload)
}

extension PushNotificationAnalyticsEvent: AnalyticsEvent {
    var name: AnalyticsEventName {
        switch self {
        case .notificationClick:
            return .pushNotificationClick
        }
    }

    var parameters: [AnalyticsParameterKey: Any]? {
        switch self {
        case let .notificationClick(payload):
            return payload.analyticsParameters
        }
    }
}

private extension PushNotificationPayload {
    var analyticsParameters: [AnalyticsParameterKey: Any]? {
        var parameters: [AnalyticsParameterKey: Any] = [:]

        if let notificationType = value(for: "notification_type", "notificationType", "type") {
            parameters[.notificationType] = notificationType
        }

        if let notificationTone = value(for: "notification_tone", "notificationTone", "tone") {
            parameters[.notificationTone] = notificationTone
        }

        return parameters.isEmpty ? nil : parameters
    }

    func value(for keys: String...) -> String? {
        keys.lazy.compactMap { values[$0] }.first
    }
}
