//
//  AppDiagnosticsClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/7/26.
//

import ComposableArchitecture

@DependencyClient
public struct AppDiagnosticsClient {
    public var fetch: @Sendable () async -> AppDiagnostics = { .empty }
}

extension AppDiagnosticsClient: DependencyKey {
    public static let liveValue = Self(
        fetch: {
            @Dependency(\.appDiagnosticsRepository) var appDiagnosticsRepository
            @Dependency(\.authRepository) var authRepository
            @Dependency(\.pushNotificationRepository) var pushNotificationRepository

            let authTokens = await authRepository.fetchStoredTokens()
            return await appDiagnosticsRepository.fetch(
                authTokens: authTokens,
                apnsTokenStatus: .from(pushNotificationRepository.fetchCurrentAPNSToken()),
                fcmTokenStatus: .from(pushNotificationRepository.fetchCurrentFCMToken())
            )
        }
    )
}

extension AppDiagnosticsClient: TestDependencyKey {
    public static let testValue = Self(
        fetch: { .empty }
    )
}

public extension DependencyValues {
    var appDiagnosticsClient: AppDiagnosticsClient {
        get { self[AppDiagnosticsClient.self] }
        set { self[AppDiagnosticsClient.self] = newValue }
    }
}
