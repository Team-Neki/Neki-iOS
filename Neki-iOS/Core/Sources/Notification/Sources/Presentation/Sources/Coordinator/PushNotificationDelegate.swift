//
//  PushNotificationDelegate.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/16/26.
//

import Foundation
import Dependencies
import UserNotifications

@MainActor
final class PushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let payload = PushNotificationPayload(userInfo: notification.request.content.userInfo)
        pushNotificationClient.processReceivedNotification(payload)
        await pushNotificationClient.publishEvent(.foregroundReceived(payload))
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let payload = PushNotificationPayload(userInfo: response.notification.request.content.userInfo)
        pushNotificationClient.processReceivedNotification(payload)
        await pushNotificationClient.publishEvent(.responseReceived(payload))
    }
}
