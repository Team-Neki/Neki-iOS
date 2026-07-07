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

public extension DependencyValues {
    var pushNotificationClient: PushNotificationClient {
        get { self[PushNotificationClient.self] }
        set { self[PushNotificationClient.self] = newValue }
    }
}
