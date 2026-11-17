//
//  NotificationGuideKindTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct NotificationGuideKindTests {
    @Test(
        "알림 권한과 이벤트·혜택 알림 동의 상태에 맞는 안내 종류를 고른다",
        arguments: [
            (NotificationPermission.enabled, true, nil),
            (.enabled, false, .consentOnly),
            (.requestable, true, .enableNotifications),
            (.requestable, false, .consentAndEnable),
            (.settingsRequired, true, .enableInSettings(includesConsent: false)),
            (.settingsRequired, false, .enableInSettings(includesConsent: true))
        ] as [(NotificationPermission, Bool, NotificationGuideKind?)]
    )
    func init_permissionAndConsent_choosesKind(
        permission: NotificationPermission,
        isMarketingAgreed: Bool,
        expected: NotificationGuideKind?
    ) {
        #expect(NotificationGuideKind(permission: permission, isMarketingAgreed: isMarketingAgreed) == expected)
    }

    @Test("알림이 켜진 사용자에게는 동의만 묻거나 아무것도 안내하지 않는다", arguments: [true, false])
    func init_enabledPermission_asksConsentOnlyOrNothing(isMarketingAgreed: Bool) {
        let kind = NotificationGuideKind(permission: .enabled, isMarketingAgreed: isMarketingAgreed)

        #expect(kind == (isMarketingAgreed ? nil : .consentOnly))
    }

    @Test(
        "안내 종류마다 확인하면 이벤트·혜택 알림 동의를 저장하는지 정한다",
        arguments: [
            (NotificationGuideKind.consentOnly, true),
            (.enableNotifications, false),
            (.consentAndEnable, true),
            (.enableInSettings(includesConsent: true), true),
            (.enableInSettings(includesConsent: false), false)
        ] as [(NotificationGuideKind, Bool)]
    )
    func savesMarketingConsent_followsKind(kind: NotificationGuideKind, savesMarketingConsent: Bool) {
        #expect(kind.savesMarketingConsent == savesMarketingConsent)
    }
}
