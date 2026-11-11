//
//  NotificationGuideModalTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct NotificationGuideModalTests {
    @Test(
        "알림 권한과 이벤트·혜택 알림 동의 상태에 맞는 모달을 고른다",
        arguments: [
            (NotificationPermission.enabled, true, nil),
            (.enabled, false, .consentOnly),
            (.requestable, true, .enableNotifications),
            (.requestable, false, .consentAndEnable),
            (.settingsRequired, true, .openSettings(includesConsent: false)),
            (.settingsRequired, false, .openSettings(includesConsent: true))
        ] as [(NotificationPermission, Bool, NotificationGuideModal?)]
    )
    func init_permissionAndConsent_choosesModal(
        permission: NotificationPermission,
        isMarketingAgreed: Bool,
        expected: NotificationGuideModal?
    ) {
        #expect(NotificationGuideModal(permission: permission, isMarketingAgreed: isMarketingAgreed) == expected)
    }

    @Test("알림이 켜진 사용자는 어떤 경우에도 설정으로 보내지 않는다", arguments: [true, false])
    func init_enabledPermission_neverOpensSettings(isMarketingAgreed: Bool) {
        let modal = NotificationGuideModal(permission: .enabled, isMarketingAgreed: isMarketingAgreed)

        #expect(modal?.nextStep != .openNotificationSettings)
        #expect(modal?.nextStep != .requestAuthorization)
    }

    @Test(
        "모달마다 동의를 저장하는지와 확인 뒤 할 일을 정한다",
        arguments: [
            (NotificationGuideModal.consentOnly, true, NotificationGuideModal.NextStep.complete),
            (.enableNotifications, false, .requestAuthorization),
            (.consentAndEnable, true, .requestAuthorization),
            (.openSettings(includesConsent: true), true, .openNotificationSettings),
            (.openSettings(includesConsent: false), false, .openNotificationSettings)
        ] as [(NotificationGuideModal, Bool, NotificationGuideModal.NextStep)]
    )
    func savesMarketingConsentAndNextStep_followModal(
        modal: NotificationGuideModal,
        savesMarketingConsent: Bool,
        nextStep: NotificationGuideModal.NextStep
    ) {
        #expect(modal.savesMarketingConsent == savesMarketingConsent)
        #expect(modal.nextStep == nextStep)
    }
}
