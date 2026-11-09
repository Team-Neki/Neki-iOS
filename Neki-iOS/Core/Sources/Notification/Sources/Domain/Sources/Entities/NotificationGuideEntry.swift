//
//  NotificationGuideEntry.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation

/// 메인 탭에 들어온 경로입니다. 알림 안내를 어떤 규칙으로 띄울지 정합니다.
public enum NotificationGuideEntry: Equatable, Sendable {
    /// 앱 실행이나 로그인으로 들어왔습니다. 업데이트 후 첫 진입 안내를 판단합니다.
    case regular
    /// 약관 동의를 마치고 들어왔습니다. 이벤트·혜택 알림에 동의했으면 OS 알림 팝업을 바로 띄웁니다.
    case afterTermsAgreement(isMarketingTermAgreed: Bool)
}
