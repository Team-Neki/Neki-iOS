//
//  DefaultAppDiagnosticsClient.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import ComposableArchitecture
import FirebaseCore
import FirebaseMessaging
import Foundation
import UserNotifications

extension AppDiagnosticsClient: DependencyKey {
    public static let liveValue = Self(
        fetch: {
            let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
            let firebaseOptions = FirebaseApp.app()?.options

            return AppDiagnostics(
                bundleIdentifier: Bundle.main.bundleIdentifier ?? "-",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-",
                distributionChannel: AppDiagnosticsEnvironment.distributionChannel(),
                firebaseProjectID: firebaseOptions?.projectID ?? "-",
                firebaseApplicationID: firebaseOptions?.googleAppID ?? "-",
                firebaseSenderID: firebaseOptions?.gcmSenderID ?? "-",
                firebaseBundleID: firebaseOptions?.bundleID ?? "-",
                apnsEnvironment: AppDiagnosticsEnvironment.apnsEnvironment(),
                apnsTokenStatus: AppDiagnosticsEnvironment.tokenStatus(Messaging.messaging().apnsToken?.hexString),
                fcmTokenStatus: AppDiagnosticsEnvironment.tokenStatus(Messaging.messaging().fcmToken),
                notificationAuthorizationStatus: notificationSettings.authorizationStatus
            )
        }
    )
}

enum AppDiagnosticsEnvironment {
    static func distributionChannel() -> String {
        #if DEBUG
        return "debug"
        #else
        guard Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" else { return "appStore" }
        return "testFlight"
        #endif
    }

    static func apnsEnvironment() -> String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    static func tokenStatus(_ token: String?) -> AppDiagnostics.TokenStatus {
        guard let token, token.isEmpty == false else { return .missing }
        return .available(value: token)
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
