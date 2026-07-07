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
    func updateAPNSToken(_ token: Data)
    func processReceivedNotification(_ payload: PushNotificationPayload)
    func updateDeviceToken(
        _ token: PushNotificationToken,
        isPushNotificationAgreed: Bool
    ) async throws
}
