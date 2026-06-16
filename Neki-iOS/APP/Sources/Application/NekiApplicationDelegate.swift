//
//  NekiApplicationDelegate.swift
//  Neki-iOS
//
//  Created by Codex on 6/14/26.
//

import UIKit
import Combine
import Dependencies
import FirebaseCore
import FirebaseMessaging
import os
import UserNotifications

final class NekiApplicationDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, ObservableObject {
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

    @Published private(set) var isAPNSTokenRegistered = false

    private let pushNotificationDelegate = PushNotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = pushNotificationDelegate
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            do {
                try await pushNotificationClient.updateAPNSToken(deviceToken)
                await MainActor.run {
                    isAPNSTokenRegistered = true
                }
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

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard fcmToken?.isEmpty == false else { return }
        Logger.data.debug("FCM 등록 토큰 갱신 감지")
    }
}
