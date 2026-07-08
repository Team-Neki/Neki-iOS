//
//  DefaultAppDiagnosticsRepository.swift
//  Neki-iOS
//
//  Created by Codex on 7/8/26.
//

import ComposableArchitecture
import FirebaseCore
import Foundation
import UserNotifications

struct DefaultAppDiagnosticsRepository: AppDiagnosticsRepository {
    func fetch(
        authTokens: AuthTokens?,
        apnsTokenStatus: AppDiagnostics.TokenStatus,
        fcmTokenStatus: AppDiagnostics.TokenStatus
    ) async -> AppDiagnostics {
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        let firebaseOptions = FirebaseApp.app()?.options
        let userSessionStatus = AppDiagnosticsEnvironment.userSessionStatus()

        return AppDiagnostics(
            userSessionStatus: userSessionStatus,
            authTokens: authTokens,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "-",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-",
            distributionChannel: AppRuntimeEnvironment.distributionChannel.rawValue,
            firebaseProjectID: firebaseOptions?.projectID ?? "-",
            firebaseApplicationID: firebaseOptions?.googleAppID ?? "-",
            firebaseSenderID: firebaseOptions?.gcmSenderID ?? "-",
            firebaseBundleID: firebaseOptions?.bundleID ?? "-",
            apnsEnvironment: AppRuntimeEnvironment.apnsEnvironment,
            apnsTokenStatus: apnsTokenStatus,
            fcmTokenStatus: fcmTokenStatus,
            notificationAuthorizationStatus: notificationSettings.authorizationStatus
        )
    }
}

private enum AppDiagnosticsEnvironment {
    static func userSessionStatus() -> UserSessionStatus {
        guard let data = UserDefaults.standard.data(forKey: AppStorageKey.userSessionStatus),
              let status = try? JSONDecoder().decode(UserSessionStatus.self, from: data)
        else { return .signedOut }
        return status
    }
}

private enum AppDiagnosticsRepositoryKey: DependencyKey {
    static let liveValue: AppDiagnosticsRepository = DefaultAppDiagnosticsRepository()
}

extension DependencyValues {
    var appDiagnosticsRepository: AppDiagnosticsRepository {
        get { self[AppDiagnosticsRepositoryKey.self] }
        set { self[AppDiagnosticsRepositoryKey.self] = newValue }
    }
}
