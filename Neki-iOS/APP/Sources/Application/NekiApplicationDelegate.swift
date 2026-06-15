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

final class NekiApplicationDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, ObservableObject {
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

    @Published private(set) var isAPNSTokenRegistered = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if DEBUG
        print("[Push] Application delegate launched")
#endif
        FirebaseApp.configure()
#if DEBUG
        print("[Push] Firebase configured: \(FirebaseApp.app() != nil)")
#endif
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
#if DEBUG
        print("[APNs] Remote notification registration requested")
#endif
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
#if DEBUG
        print("[APNs] Device token received (\(deviceToken.count) bytes)")
#endif
        Task {
            do {
                try await pushNotificationClient.updateAPNSToken(deviceToken)
#if DEBUG
                print("[APNs] Device token assigned to Firebase Messaging")
#endif
                await MainActor.run {
                    isAPNSTokenRegistered = true
                    printCurrentFCMToken()
                }
            } catch {
#if DEBUG
                print("[APNs] Device token assignment failed: \(error)")
#endif
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
#if DEBUG
        print("[APNs] Registration failed: \(error)")
#endif
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
#if DEBUG
        guard let fcmToken, fcmToken.isEmpty == false else {
            print("[FCM] Registration token callback returned an empty token")
            return
        }
        print("[FCM] Registration Token: \(fcmToken)")
#endif
    }

    private func printCurrentFCMToken() {
#if DEBUG
        Messaging.messaging().token { token, error in
            if let error {
                print("[FCM] Token retrieval failed: \(error)")
            } else if let token, token.isEmpty == false {
                print("[FCM] Current Token: \(token)")
            } else {
                print("[FCM] Token retrieval returned an empty token")
            }
        }
#endif
    }
}
