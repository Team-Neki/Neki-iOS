//
//  NotificationGuideRecord.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation

/// 자동 알림 안내를 언제 띄웠고 어느 앱 버전에서 판단했는지 사용자별로 남긴 기록입니다.
struct NotificationGuideRecord: Codable, Equatable, Sendable {
    /// 마지막으로 자동 안내를 띄운 한국 시간 날짜입니다. 자동 안내는 경로와 상관없이 하루에 한 번만 띄웁니다.
    var lastAutomaticGuideDay: KSTDay?
    /// 업데이트 후 첫 진입 안내를 판단한 앱 버전입니다. 버전마다 한 번만 판단합니다.
    var updateEntryJudgedVersion: String?

    init(lastAutomaticGuideDay: KSTDay? = nil, updateEntryJudgedVersion: String? = nil) {
        self.lastAutomaticGuideDay = lastAutomaticGuideDay
        self.updateEntryJudgedVersion = updateEntryJudgedVersion
    }

    /// 판단 결과를 기록에 남깁니다.
    ///
    /// 모달을 띄울 때 버전과 날짜를 함께 남기므로, 취소·OS 거부·설정에서 켜지 않음은 모두 다음 버전까지 다시 띄우지 않습니다.
    mutating func apply(_ decision: NotificationGuideDecision, today: KSTDay, appVersion: String) {
        switch decision {
        case .skip:
            return
        case .markJudged:
            updateEntryJudgedVersion = appVersion
        case .present:
            updateEntryJudgedVersion = appVersion
            lastAutomaticGuideDay = today
        }
    }
}

/// 업데이트 후 첫 진입에서 알림 안내를 어떻게 할지 정한 결과입니다.
enum NotificationGuideDecision: Equatable, Sendable {
    /// 이번엔 판단하지 않습니다. 기록도 남기지 않아 다음 실행에 다시 판단합니다.
    case skip
    /// 띄울 모달이 없어 이 버전을 판단한 것으로만 남깁니다.
    case markJudged
    /// 모달을 띄웁니다.
    case present(NotificationGuideModal)

    /// 오늘 다른 자동 안내를 띄웠는지, 이 버전을 판단했는지를 먼저 보고, 그다음 상태에 맞는 모달을 고릅니다.
    static func updateEntry(
        record: NotificationGuideRecord,
        today: KSTDay,
        appVersion: String,
        permission: NotificationPermission,
        isMarketingAgreed: Bool
    ) -> Self {
        guard record.lastAutomaticGuideDay != today else { return .skip }
        guard record.updateEntryJudgedVersion != appVersion else { return .skip }
        guard let modal = NotificationGuideModal(permission: permission, isMarketingAgreed: isMarketingAgreed) else {
            return .markJudged
        }
        return .present(modal)
    }
}
