//
//  NotificationGuideModal.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation

/// 알림 권한과 이벤트·혜택 알림 동의 상태에 맞춰 띄우는 안내 모달입니다.
enum NotificationGuideModal: Equatable, Sendable {
    /// 알림은 켜져 있어 이벤트·혜택 알림 동의만 받습니다.
    case consentOnly
    /// 동의했지만 알림이 꺼져 있어 OS 알림 팝업을 띄웁니다.
    case enableNotifications
    /// 알림도 꺼져 있고 동의도 하지 않아, 동의를 저장한 뒤 OS 알림 팝업을 띄웁니다.
    case consentAndEnable
    /// OS 알림 팝업을 다시 띄울 수 없어 알림 설정으로 안내합니다. 동의하지 않았으면 동의도 함께 저장합니다.
    case openSettings(includesConsent: Bool)

    /// 확인 버튼을 누른 뒤 할 일입니다.
    enum NextStep: Equatable, Sendable {
        /// 더 할 일 없이 마무리합니다.
        case complete
        case requestAuthorization
        case openNotificationSettings
    }

    /// 상태에 맞는 모달입니다. 알림이 켜져 있고 동의도 했으면 띄우지 않습니다.
    ///
    /// 알림이 켜진 사용자는 설정으로 보내지 않습니다.
    init?(permission: NotificationPermission, isMarketingAgreed: Bool) {
        switch (permission, isMarketingAgreed) {
        case (.enabled, true):
            return nil
        case (.enabled, false):
            self = .consentOnly
        case (.requestable, true):
            self = .enableNotifications
        case (.requestable, false):
            self = .consentAndEnable
        case let (.settingsRequired, isAgreed):
            self = .openSettings(includesConsent: isAgreed == false)
        }
    }

    /// 확인 버튼을 누르면 이벤트·혜택 알림 동의를 저장하는지입니다.
    var savesMarketingConsent: Bool {
        switch self {
        case .consentOnly, .consentAndEnable:
            true
        case .enableNotifications:
            false
        case let .openSettings(includesConsent):
            includesConsent
        }
    }

    var nextStep: NextStep {
        switch self {
        case .consentOnly:
            .complete
        case .enableNotifications, .consentAndEnable:
            .requestAuthorization
        case .openSettings:
            .openNotificationSettings
        }
    }
}
