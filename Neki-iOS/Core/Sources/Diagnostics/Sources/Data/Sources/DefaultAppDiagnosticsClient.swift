//
//  DefaultAppDiagnosticsClient.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import ComposableArchitecture
import FirebaseCore
import Foundation
import UserNotifications

extension AppDiagnosticsClient: DependencyKey {
    public static let liveValue = Self(
        fetch: {
            @Dependency(\.pushNotificationClient) var pushNotificationClient

            let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
            let firebaseOptions = FirebaseApp.app()?.options
            let userSessionStatus = AppDiagnosticsEnvironment.userSessionStatus()

            return AppDiagnostics(
                userSessionStatus: userSessionStatus,
                bundleIdentifier: Bundle.main.bundleIdentifier ?? "-",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-",
                distributionChannel: AppRuntimeEnvironment.distributionChannel.rawValue,
                firebaseProjectID: firebaseOptions?.projectID ?? "-",
                firebaseApplicationID: firebaseOptions?.googleAppID ?? "-",
                firebaseSenderID: firebaseOptions?.gcmSenderID ?? "-",
                firebaseBundleID: firebaseOptions?.bundleID ?? "-",
                apnsEnvironment: AppRuntimeEnvironment.apnsEnvironment,
                apnsTokenStatus: AppDiagnosticsEnvironment.tokenStatus(pushNotificationClient.fetchCurrentAPNSToken()),
                fcmTokenStatus: AppDiagnosticsEnvironment.tokenStatus(pushNotificationClient.fetchCurrentFCMToken()),
                notificationAuthorizationStatus: notificationSettings.authorizationStatus
            )
        }
    )
}

enum AppDiagnosticsEnvironment {
    static func userSessionStatus() -> UserSessionStatus {
        guard let data = UserDefaults.standard.data(forKey: AppStorageKey.userSessionStatus),
              let status = try? JSONDecoder().decode(UserSessionStatus.self, from: data)
        else { return .signedOut }
        return status
    }

    static func tokenStatus(_ token: String?) -> AppDiagnostics.TokenStatus {
        guard let token, token.isEmpty == false else { return .missing }
        return .available(value: token)
    }
}
