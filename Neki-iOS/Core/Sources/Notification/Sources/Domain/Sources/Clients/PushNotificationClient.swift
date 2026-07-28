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
    public var fetchNotificationList: @Sendable () async throws -> [PushNotificationListItem]
    public var synchronizeDeviceToken: @Sendable () async throws -> UNAuthorizationStatus
    public var checkAPNSTokenRegistration: @Sendable () -> Bool = { false }
    public var fetchCurrentAPNSToken: @Sendable () -> String? = { nil }
    public var fetchCurrentFCMToken: @Sendable () -> String? = { nil }
    public var configureMessaging: @Sendable () -> Void = {}
    public var updateAPNSToken: @Sendable (_ token: Data) async throws -> Void
    public var processReceivedNotification: @Sendable (PushNotificationPayload) -> Void = { _ in }
    public var events: @Sendable () async -> AsyncStream<PushNotificationEvent> = {
        AsyncStream { $0.finish() }
    }
    public var publishEvent: @Sendable (PushNotificationEvent) async -> Void = { _ in }
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
            fetchNotificationList: {
                try await repository.fetchNotificationList()
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
            checkAPNSTokenRegistration: {
                repository.checkAPNSTokenRegistration()
            },
            fetchCurrentAPNSToken: {
                repository.fetchCurrentAPNSToken()
            },
            fetchCurrentFCMToken: {
                repository.fetchCurrentFCMToken()
            },
            configureMessaging: {
                repository.configureMessaging()
            },
            updateAPNSToken: { token in
                repository.updateAPNSToken(token)
            },
            processReceivedNotification: { payload in
                repository.processReceivedNotification(payload)
            },
            events: { await repository.events() },
            publishEvent: { await repository.publishEvent($0) }
        )
    }()
}

extension PushNotificationClient: TestDependencyKey {
    public static let testValue = PushNotificationClient(
        checkAuthorizationStatus: { .notDetermined },
        requestAuthorization: { false },
        fetchNotificationList: { [] },
        synchronizeDeviceToken: { .notDetermined },
        checkAPNSTokenRegistration: { false },
        fetchCurrentAPNSToken: { nil },
        fetchCurrentFCMToken: { nil },
        configureMessaging: {},
        updateAPNSToken: { _ in },
        processReceivedNotification: { _ in },
        events: { AsyncStream { $0.finish() } },
        publishEvent: { _ in }
    )
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

public extension DependencyValues {
    var pushNotificationClient: PushNotificationClient {
        get { self[PushNotificationClient.self] }
        set { self[PushNotificationClient.self] = newValue }
    }
}
