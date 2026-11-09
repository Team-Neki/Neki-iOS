//
//  NotificationPermissionTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation
import Testing
import UserNotifications
@testable import Neki_iOS

struct NotificationPermissionTests {
    @Test("허용과 임시 허용은 알림이 켜진 것으로 본다", arguments: [UNAuthorizationStatus.authorized, .provisional, .ephemeral])
    func init_allowedStatus_isEnabled(status: UNAuthorizationStatus) {
        #expect(NotificationPermission(status) == .enabled)
    }

    @Test("아직 묻지 않았으면 OS 알림 팝업을 띄울 수 있다")
    func init_notDetermined_isRequestable() {
        #expect(NotificationPermission(.notDetermined) == .requestable)
    }

    @Test("거부했으면 설정에서만 켤 수 있다")
    func init_denied_isSettingsRequired() {
        #expect(NotificationPermission(.denied) == .settingsRequired)
    }
}
