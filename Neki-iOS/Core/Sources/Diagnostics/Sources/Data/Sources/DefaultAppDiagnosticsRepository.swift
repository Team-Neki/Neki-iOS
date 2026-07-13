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
        let userSessionStatus = AppDiagnosticsEnvironment.userSessionStatus()

        return AppDiagnostics(
            userSessionStatus: userSessionStatus,
            authTokens: authTokens,
            appSection: AppDiagnosticsEnvironment.appSection,
            firebaseSection: AppDiagnosticsEnvironment.firebaseSection,
            apnsEnvironment: AppRuntimeEnvironment.apnsEnvironment,
            apnsTokenStatus: apnsTokenStatus,
            fcmTokenStatus: fcmTokenStatus,
            notificationAuthorizationStatus: notificationSettings.authorizationStatus
        )
    }
}

private enum AppDiagnosticsEnvironment {
    static let appSection = AppDiagnostics.Section(
        title: "앱",
        rows: [
            .init(title: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "-"),
            .init(title: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"),
            .init(title: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"),
            .init(title: "Distribution", value: AppRuntimeEnvironment.distributionChannel.rawValue)
        ]
    )

    static let firebaseSection = AppDiagnostics.Section(
        title: "Firebase",
        rows: {
            let firebaseOptions = FirebaseApp.app()?.options
            return [
                .init(title: "Project ID", value: firebaseOptions?.projectID ?? "-"),
                .init(title: "App ID", value: firebaseOptions?.googleAppID ?? "-"),
                .init(title: "Sender ID", value: firebaseOptions?.gcmSenderID ?? "-"),
                .init(title: "Bundle ID", value: firebaseOptions?.bundleID ?? "-")
            ]
        }()
    )

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
