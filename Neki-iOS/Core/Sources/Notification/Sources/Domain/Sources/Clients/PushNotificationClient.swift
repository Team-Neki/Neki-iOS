//
//  PushNotificationClient.swift
//  Neki-iOS
//
//  Created by Codex on 6/7/26.
//

import Foundation
import ComposableArchitecture
import UserNotifications

@DependencyClient
public struct PushNotificationClient {
    public var checkAuthorizationStatus: @Sendable () async throws -> UNAuthorizationStatus
    public var requestAuthorization: @Sendable () async throws -> Bool
    public var synchronizeDeviceToken: @Sendable () async throws -> UNAuthorizationStatus
    public var updateAPNSToken: @Sendable (_ token: Data) async throws -> Void
}

extension PushNotificationClient: DependencyKey {
    public static let liveValue: PushNotificationClient = {
        @Dependency(\.pushNotificationRepository) var repository

        return PushNotificationClient(
            checkAuthorizationStatus: {
                await repository.checkAuthorizationStatus()
            },
            requestAuthorization: {
                try await repository.requestAuthorization()
            },
            synchronizeDeviceToken: {
                let deviceToken = try await repository.fetchFCMToken()
                let authorizationStatus = await repository.checkAuthorizationStatus()
                try await repository.updateDeviceToken(
                    deviceToken,
                    isPushNotificationAgreed: authorizationStatus.isPushNotificationAgreed
                )
                return authorizationStatus
            },
            updateAPNSToken: { token in
                repository.updateAPNSToken(token)
            }
        )
    }()
}

extension PushNotificationClient: TestDependencyKey {
    public static let testValue = PushNotificationClient(
        checkAuthorizationStatus: { .notDetermined },
        requestAuthorization: { false },
        synchronizeDeviceToken: { .notDetermined },
        updateAPNSToken: { _ in }
    )
}

public extension DependencyValues {
    var pushNotificationClient: PushNotificationClient {
        get { self[PushNotificationClient.self] }
        set { self[PushNotificationClient.self] = newValue }
    }
}

private extension UNAuthorizationStatus {
    var isPushNotificationAgreed: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}
