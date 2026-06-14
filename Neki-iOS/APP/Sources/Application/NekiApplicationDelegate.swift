//
//  NekiApplicationDelegate.swift
//  Neki-iOS
//
//  Created by Codex on 6/14/26.
//

import UIKit
import Dependencies

extension Notification.Name {
    static let didRegisterAPNSToken = Notification.Name("didRegisterAPNSToken")
}

final class NekiApplicationDelegate: NSObject, UIApplicationDelegate {
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            try? await pushNotificationClient.updateAPNSToken(deviceToken)
            await MainActor.run { NotificationCenter.default.post(name: .didRegisterAPNSToken, object: nil) }
        }
    }
}
