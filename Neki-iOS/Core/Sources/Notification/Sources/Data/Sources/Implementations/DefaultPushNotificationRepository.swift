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
    @Dependency(\.networkProvider) private var networkProvider

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func fetchNotificationList() async throws -> [PushNotificationListItem] {
        // TODO: Replace this stub with the real notification list API when the server contract is finalized.
        []
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

    nonisolated func updateAPNSToken(_ token: Data) {
        Messaging.messaging().apnsToken = token
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

private enum PushNotificationRepositoryError: Error {
    case missingAPNSToken
    case missingFCMToken
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
