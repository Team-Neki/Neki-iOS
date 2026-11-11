//
//  NotificationGuideCopyTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct NotificationGuideCopyTests {
    @Test(
        "모달마다 확정 문구와 버튼을 쓴다",
        arguments: [
            (
                NotificationGuideModal.consentOnly,
                "새로운 브랜드·이벤트 소식을\n알림으로 받아보세요.\n(광고성 정보 수신 동의)",
                "알림 받기"
            ),
            (
                .enableNotifications,
                "새로운 소식과 콘텐츠를 놓치지 않도록\n기기 알림을 켜주세요.",
                "알림 받기"
            ),
            (
                .consentAndEnable,
                "새로운 소식과 콘텐츠를 놓치지 않도록\n알림을 켜주세요.\n(광고성 정보 수신 동의 포함)",
                "알림 받기"
            ),
            (
                .openSettings(includesConsent: true),
                "설정 > 알림에서 켤 수 있어요.\n(광고성 정보 수신 동의 포함)",
                "설정에서 켜기"
            ),
            (
                .openSettings(includesConsent: false),
                "설정 > 알림에서 켤 수 있어요.",
                "설정에서 켜기"
            )
        ] as [(NotificationGuideModal, String, String)]
    )
    func copy_followsConfirmedText(modal: NotificationGuideModal, message: String, confirmButtonTitle: String) {
        #expect(modal.title == "놓치고 있던 소식들이 있어요!")
        #expect(modal.message == message)
        #expect(modal.confirmButtonTitle == confirmButtonTitle)
        #expect(NotificationGuideModal.cancelButtonTitle == "다음에 하기")
    }

    @Test("동의 토스트는 동의한 한국 시간 날짜를 보여 준다")
    func marketingConsentAgreed_showsKSTDate() throws {
        let agreedAt = try #require(ISO8601DateFormatter().date(from: "2026-10-19T15:30:00Z"))

        let toast = NekiToastItem.marketingConsentAgreed(at: agreedAt)

        #expect(toast.message == "10.20 이벤트·혜택 알림에 동의했어요.")
        #expect(toast.style == .success)
    }

    @Test("동의 저장 실패 토스트는 오류로 보여 준다")
    func marketingConsentFailed_isError() {
        let toast = NekiToastItem.marketingConsentFailed()

        #expect(toast.message == "이벤트·혜택 알림 동의에 실패했어요")
        #expect(toast.style == .error)
    }
}
