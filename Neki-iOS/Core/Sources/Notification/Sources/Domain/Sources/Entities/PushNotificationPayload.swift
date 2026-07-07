//
//  PushNotificationPayload.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import Foundation

public struct PushNotificationPayload: Equatable, @unchecked Sendable {
    let userInfo: [AnyHashable: Any]
    public let values: [String: String]

    public init(userInfo: [AnyHashable: Any]) {
        self.userInfo = userInfo
        self.values = userInfo.reduce(into: [:]) { result, element in
            guard let key = element.key as? String else { return }

            switch element.value {
            case let value as String:
                result[key] = value
            case let value as Int:
                result[key] = String(value)
            case let value as Int64:
                result[key] = String(value)
            case let value as Double:
                result[key] = String(value)
            case let value as Bool:
                result[key] = String(value)
            default:
                return
            }
        }
    }

    public static func == (
        lhs: PushNotificationPayload,
        rhs: PushNotificationPayload
    ) -> Bool {
        lhs.values == rhs.values
    }
}

public enum PushNotificationEvent: Equatable, Sendable {
    case apnsTokenRegistered
    case fcmRegistrationTokenReceived
    case foregroundReceived(PushNotificationPayload)
    case responseReceived(PushNotificationPayload)
}
