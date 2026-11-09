//
//  NotificationGuideModal+.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation

extension NotificationGuideModal {
    static let cancelButtonTitle = "다음에 하기"

    var title: String {
        "놓치고 있던 소식들이 있어요!"
    }

    var message: String {
        switch self {
        case .consentOnly:
            "새로운 브랜드·이벤트 소식을\n알림으로 받아보세요.\n(광고성 정보 수신 동의)"
        case .enableNotifications:
            "새로운 소식과 콘텐츠를 놓치지 않도록\n기기 알림을 켜주세요."
        case .consentAndEnable:
            "새로운 소식과 콘텐츠를 놓치지 않도록\n알림을 켜주세요.\n(광고성 정보 수신 동의 포함)"
        case .openSettings(includesConsent: true):
            "설정 > 알림에서 켤 수 있어요.\n(광고성 정보 수신 동의 포함)"
        case .openSettings(includesConsent: false):
            "설정 > 알림에서 켤 수 있어요."
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .consentOnly, .enableNotifications, .consentAndEnable:
            "알림 받기"
        case .openSettings:
            "설정에서 켜기"
        }
    }
}

extension NekiToastItem {
    /// 이벤트·혜택 알림 동의를 저장했을 때 동의한 날짜와 함께 알립니다.
    ///
    /// 토스트는 매번 새로 만들어야 다시 보입니다.
    static func marketingConsentAgreed(at date: Date) -> NekiToastItem {
        NekiToastItem("\(date.kstDay.monthDayText) 이벤트·혜택 알림에 동의했어요.", style: .success)
    }

    static func marketingConsentFailed() -> NekiToastItem {
        NekiToastItem("이벤트·혜택 알림 동의에 실패했어요", style: .error)
    }
}
