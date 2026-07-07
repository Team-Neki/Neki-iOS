//
//  NekiApplicationDelegate.swift
//  Neki-iOS
//
//  Created by Codex on 6/14/26.
//

import UIKit
import Dependencies
import FirebaseCore
import os
import UserNotifications

final class NekiApplicationDelegate: NSObject, UIApplicationDelegate {
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

    private let pushNotificationDelegate = PushNotificationDelegate()

    deinit {}

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        pushNotificationClient.configureMessaging()
        UNUserNotificationCenter.current().delegate = pushNotificationDelegate
        application.registerForRemoteNotifications()
        Logger.data.debug("APNs 원격 알림 등록 요청")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            do {
                try await pushNotificationClient.updateAPNSToken(deviceToken)
                Logger.data.debug("APNs 토큰 등록 감지")
                await pushNotificationClient.publishEvent(.apnsTokenRegistered)
            } catch {
                Logger.data.error("APNs 토큰을 Firebase Messaging에 전달하지 못함: \(error)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.data.error("APNs 원격 알림 등록 실패: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let payload = PushNotificationPayload(userInfo: userInfo)
        pushNotificationClient.processReceivedNotification(payload)
        if application.applicationState == .active {
            let notificationClient = pushNotificationClient
            Task { await notificationClient.publishEvent(.foregroundReceived(payload)) }
        }
        completionHandler(.noData)
    }
}
