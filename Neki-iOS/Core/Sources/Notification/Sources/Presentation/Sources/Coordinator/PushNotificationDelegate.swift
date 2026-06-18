//
//  PushNotificationDelegate.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import Foundation
import UserNotifications

@MainActor
final class PushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let eventBroker: PushNotificationEventBroker

    init(eventBroker: PushNotificationEventBroker = .shared) {
        self.eventBroker = eventBroker
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let payload = PushNotificationPayload(userInfo: notification.request.content.userInfo)
        await eventBroker.publish(.foregroundReceived(payload))
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let payload = PushNotificationPayload(userInfo: response.notification.request.content.userInfo)
        await eventBroker.publish(.responseReceived(payload))
    }
}
