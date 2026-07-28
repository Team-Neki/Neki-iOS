//
//  PushNotificationAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import Foundation

enum PushNotificationAnalyticsEvent {
    case notificationSent(
        notificationType: String,
        targetType: String,
        messageTone: String,
        hasVariable: Bool
    )
    case notificationClick(payload: PushNotificationPayload)
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

    var parameters: [AnalyticsParameterKey: Any]? {
        switch self {
        case let .notificationSent(notificationType, targetType, messageTone, hasVariable):
            return [
                .notificationType: notificationType,
                .targetType: targetType,
                .messageTone: messageTone,
                .hasVariable: hasVariable
            ]
        case let .notificationClick(payload):
            return payload.analyticsParameters
        }
    }
}

private extension PushNotificationPayload {
    var analyticsParameters: [AnalyticsParameterKey: Any]? {
        var parameters: [AnalyticsParameterKey: Any] = [:]

        if let notificationType = values["notification_type"] {
            parameters[.notificationType] = notificationType
        }

        if let messageTone = values["message_tone"] {
            parameters[.messageTone] = messageTone
        }

        if let hasVariable = boolValue(for: "has_variable") {
            parameters[.hasVariable] = hasVariable
        }

        return parameters.isEmpty ? nil : parameters
    }

    func boolValue(for key: String) -> Bool? {
        guard let value = values[key]?.lowercased() else { return nil }
        switch value {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
}
