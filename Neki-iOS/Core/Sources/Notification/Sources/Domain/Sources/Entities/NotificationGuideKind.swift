//
//  NotificationGuideKind.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation

/// 알림 권한과 이벤트·혜택 알림 동의 상태에 따라 필요한 안내 종류입니다.
enum NotificationGuideKind: Equatable, Sendable {
    /// 알림은 켜져 있어 이벤트·혜택 알림 동의만 받습니다.
    case consentOnly
    /// 동의했지만 알림이 꺼져 있습니다. OS 알림 팝업으로 켤 수 있습니다.
    case enableNotifications
    /// 알림도 꺼져 있고 동의도 하지 않아 둘을 함께 안내합니다. 알림은 OS 알림 팝업으로 켤 수 있습니다.
    case consentAndEnable
    /// OS 알림 팝업을 다시 띄울 수 없어 알림 설정으로 안내합니다. 동의하지 않았으면 동의도 함께 저장합니다.
    case enableInSettings(includesConsent: Bool)

    /// 상태에 맞는 안내 종류입니다. 알림이 켜져 있고 동의도 했으면 안내하지 않습니다.
    ///
    /// 알림이 켜진 사용자에게는 설정에서 켜기를 안내하지 않습니다.
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
            self = .enableInSettings(includesConsent: isAgreed == false)
        }
    }

    /// 확인 버튼을 누르면 이벤트·혜택 알림 동의를 저장하는지입니다.
    var savesMarketingConsent: Bool {
        switch self {
        case .consentOnly, .consentAndEnable:
            true
        case .enableNotifications:
            false
        case let .enableInSettings(includesConsent):
            includesConsent
        }
    }
}
