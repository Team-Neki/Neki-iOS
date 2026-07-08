//
//  DefaultPushNotificationRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/13/26.
//

import Foundation
import Dependencies
import FirebaseMessaging
import UserNotifications

final actor DefaultPushNotificationRepository: PushNotificationRepository {
    private let notificationCenter: UNUserNotificationCenter
    private let eventBroker: PushNotificationEventBroker
    private let messagingDelegate: FirebaseMessagingDelegateProxy
    @Dependency(\.networkProvider) private var networkProvider

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        eventBroker: PushNotificationEventBroker = PushNotificationEventBroker()
    ) {
        self.notificationCenter = notificationCenter
        self.eventBroker = eventBroker
        self.messagingDelegate = FirebaseMessagingDelegateProxy(
            publishEvent: { await eventBroker.publish($0) }
        )
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func fetchNotificationList() async throws -> [PushNotificationListItem] {
        let endpoint = PushNotificationEndpoint.fetchRecentNotifications
        let responseDTO: BaseResponseDTO<FetchRecentPushNotificationsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
        return data.map { $0.toEntity() }
    }

    func fetchFCMToken() async throws -> PushNotificationToken {
        guard Messaging.messaging().apnsToken != nil else { throw PushNotificationRepositoryError.missingAPNSToken }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PushNotificationToken, Error>) in
            Messaging.messaging().token { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token, token.isEmpty == false {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: PushNotificationRepositoryError.missingFCMToken)
                }
            }
        }
    }

    nonisolated func checkAPNSTokenRegistration() -> Bool {
        Messaging.messaging().apnsToken != nil
    }

    nonisolated func fetchCurrentAPNSToken() -> String? {
        Messaging.messaging().apnsToken?.hexString
    }

    nonisolated func fetchCurrentFCMToken() -> String? {
        Messaging.messaging().fcmToken
    }

    nonisolated func configureMessaging() {
        messagingDelegate.configureMessaging()
    }

    nonisolated func updateAPNSToken(_ token: Data) {
        Messaging.messaging().setAPNSToken(token, type: PushNotificationAPNSTokenEnvironment.currentTokenType())
    }

    nonisolated func processReceivedNotification(_ payload: PushNotificationPayload) {
        Messaging.messaging().appDidReceiveMessage(payload.userInfo)
    }

    func events() async -> AsyncStream<PushNotificationEvent> {
        await eventBroker.events()
    }

    func publishEvent(_ event: PushNotificationEvent) async {
        await eventBroker.publish(event)
    }

    func updateDeviceToken(
        _ token: PushNotificationToken,
        isPushNotificationAgreed: Bool
    ) async throws {
        let dto = FCMDeviceTokenDTO.Request(
            deviceToken: token,
            isPushNotificationAgreed: isPushNotificationAgreed
        )
        let endpoint = PushNotificationEndpoint.setDeviceToken(dto: dto)
        let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private enum PushNotificationRepositoryError: Error {
    case missingAPNSToken
    case missingFCMToken
}

private enum PushNotificationAPNSTokenEnvironment {
    static func currentTokenType() -> MessagingAPNSTokenType {
        #if DEBUG
        return .sandbox
        #else
        return .prod
        #endif
    }
}

private enum PushNotificationRepositoryKey: DependencyKey {
    static let liveValue: any PushNotificationRepository = DefaultPushNotificationRepository()
}

extension DependencyValues {
    var pushNotificationRepository: any PushNotificationRepository {
        get { self[PushNotificationRepositoryKey.self] }
        set { self[PushNotificationRepositoryKey.self] = newValue }
    }
}
