//
//  PushNotificationEventBroker.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import Foundation
import ComposableArchitecture
import FirebaseMessaging
import os
import UserNotifications

private actor PushNotificationEventBroker {
    private var continuations: [UUID: AsyncStream<PushNotificationEvent>.Continuation] = [:]
    private var pendingEvents: [PushNotificationEvent] = []

    deinit {
        continuations.values.forEach { $0.finish() }
    }

    func events() -> AsyncStream<PushNotificationEvent> {
        let id = UUID()

        return AsyncStream { continuation in
            Task { self.addContinuation(continuation, id: id) }

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    func publish(_ event: PushNotificationEvent) {
        guard continuations.isEmpty == false else {
            pendingEvents.append(event)
            return
        }

        continuations.values.forEach { $0.yield(event) }
    }

    private func addContinuation(
        _ continuation: AsyncStream<PushNotificationEvent>.Continuation,
        id: UUID
    ) {
        continuations[id] = continuation
        pendingEvents.forEach { continuation.yield($0) }
        pendingEvents.removeAll()
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

private final class FirebaseMessagingDelegateProxy: NSObject, MessagingDelegate, @unchecked Sendable {
    private let publishEvent: @Sendable (PushNotificationEvent) async -> Void

    init(publishEvent: @escaping @Sendable (PushNotificationEvent) async -> Void) {
        self.publishEvent = publishEvent
    }
    
    deinit {}

    func configureMessaging() {
        Messaging.messaging().delegate = self
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard fcmToken?.isEmpty == false else {
            Logger.data.error("FCM 등록 토큰 갱신 콜백에 유효한 토큰이 없음")
            return
        }
        guard messaging.apnsToken != nil else {
            Logger.data.debug("APNs 연결 전 FCM 등록 토큰 갱신 이벤트 무시")
            return
        }
        Logger.data.debug("FCM 등록 토큰 갱신 감지")
        Task { await publishEvent(.fcmRegistrationTokenReceived) }
    }
}


// MARK: - PushNotificationClient + DependencyKey

extension PushNotificationClient: DependencyKey {
    public static let liveValue: PushNotificationClient = {
        @Dependency(\.pushNotificationRepository) var repository
        let broker = PushNotificationEventBroker()
        let messagingDelegate = FirebaseMessagingDelegateProxy(
            publishEvent: { await broker.publish($0) }
        )

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
                Messaging.messaging().apnsToken != nil
            },
            configureMessaging: {
                messagingDelegate.configureMessaging()
            },
            updateAPNSToken: { token in
                repository.updateAPNSToken(token)
            },
            processReceivedNotification: { payload in
                repository.processReceivedNotification(payload)
            },
            events: { await broker.events() },
            publishEvent: { await broker.publish($0) }
        )
    }()
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
