//
//  PushNotificationPayload.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import Foundation

public struct PushNotificationPayload: Equatable, Sendable {
    public let values: [String: String]

    public init(userInfo: [AnyHashable: Any]) {
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
}

public enum PushNotificationEvent: Equatable, Sendable {
    case foregroundReceived(PushNotificationPayload)
    case responseReceived(PushNotificationPayload)
}
