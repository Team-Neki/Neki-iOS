//
//  NotificationPermission.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation
import UserNotifications

/// 기기 알림 권한을 알림 안내에서 쓰는 세 가지 상태로 나눈 값입니다.
enum NotificationPermission: Equatable, Sendable {
    /// 알림이 켜져 있습니다(허용, 임시 허용, 앱 클립 임시 허용).
    case enabled
    /// 아직 묻지 않아 OS 알림 팝업을 띄울 수 있습니다.
    case requestable
    /// 거부해서 OS 알림 팝업을 다시 띄울 수 없습니다. 설정에서만 켤 수 있습니다.
    case settingsRequired

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            self = .enabled
        case .notDetermined:
            self = .requestable
        case .denied:
            self = .settingsRequired
        @unknown default:
            self = .settingsRequired
        }
    }
}
