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

    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        switch self {
        case let .notificationSent(notificationType, targetType, messageTone, hasVariable):
            return [
                .notificationType: .string(notificationType),
                .targetType: .string(targetType),
                .messageTone: .string(messageTone),
                .hasVariable: .boolean(hasVariable)
            ]
        case let .notificationClick(payload):
            return payload.analyticsParameters
        }
    }
}

private extension PushNotificationPayload {
    var analyticsParameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        var parameters: [AnalyticsParameterKey: AnalyticsParameterValue] = [:]

        if let notificationType = values["notification_type"] {
            parameters[.notificationType] = .string(notificationType)
        }

        if let messageTone = values["message_tone"] {
            parameters[.messageTone] = .string(messageTone)
        }

        if let hasVariable = boolValue(for: "has_variable") {
            parameters[.hasVariable] = .boolean(hasVariable)
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
