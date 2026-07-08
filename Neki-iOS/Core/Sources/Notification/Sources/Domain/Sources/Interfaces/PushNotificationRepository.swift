//
//  PushNotificationRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/13/26.
//

import Foundation
import UserNotifications

protocol PushNotificationRepository {
    func checkAuthorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func fetchNotificationList() async throws -> [PushNotificationListItem]
    func fetchFCMToken() async throws -> PushNotificationToken
    func checkAPNSTokenRegistration() -> Bool
    func fetchCurrentAPNSToken() -> String?
    func fetchCurrentFCMToken() -> String?
    func configureMessaging()
    func updateAPNSToken(_ token: Data)
    func processReceivedNotification(_ payload: PushNotificationPayload)
    func events() async -> AsyncStream<PushNotificationEvent>
    func publishEvent(_ event: PushNotificationEvent) async
    func updateDeviceToken(
        _ token: PushNotificationToken,
        isPushNotificationAgreed: Bool
    ) async throws
}
