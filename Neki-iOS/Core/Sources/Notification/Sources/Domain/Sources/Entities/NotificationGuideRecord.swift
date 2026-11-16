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
    /// 지점 상세 진입에서 마지막으로 안내한 한국 시간 날짜입니다. 이 경로는 안내한 날부터 7일 안에는 다시 안내하지 않습니다.
    var photoBoothDetailGuidedDay: KSTDay?

    init(
        lastAutomaticGuideDay: KSTDay? = nil,
        updateEntryJudgedVersion: String? = nil,
        photoBoothDetailGuidedDay: KSTDay? = nil
    ) {
        self.lastAutomaticGuideDay = lastAutomaticGuideDay
        self.updateEntryJudgedVersion = updateEntryJudgedVersion
        self.photoBoothDetailGuidedDay = photoBoothDetailGuidedDay
    }

    /// 사용자별 기록을 저장하는 키입니다.
    static func storageKey(userID: Int) -> String {
        "NotificationGuideRecord_\(userID)"
    }

    /// 업데이트 후 첫 진입의 판단 결과를 기록에 남깁니다.
    ///
    /// 안내할 때 버전과 날짜를 함께 남기므로, 취소·OS 거부·설정에서 켜지 않음은 모두 다음 버전까지 다시 띄우지 않습니다.
    mutating func applyUpdateEntry(_ decision: NotificationGuideDecision, today: KSTDay, appVersion: String) {
        switch decision {
        case .skip:
            return
        case .markJudged:
            updateEntryJudgedVersion = appVersion
        case .guide:
            updateEntryJudgedVersion = appVersion
            lastAutomaticGuideDay = today
        }
    }

    /// 지점 상세 진입의 판단 결과를 기록에 남깁니다.
    ///
    /// 안내할 때 이 경로의 날짜도 함께 남기므로, 취소·OS 거부·설정에서 켜지 않음은 모두 7일 뒤에 다시 안내합니다.
    mutating func applyPhotoBoothDetail(_ decision: NotificationGuideDecision, today: KSTDay) {
        guard case .guide = decision else { return }
        lastAutomaticGuideDay = today
        photoBoothDetailGuidedDay = today
    }
}

/// 자동 알림 안내를 어떻게 할지 정한 결과입니다.
enum NotificationGuideDecision: Equatable, Sendable {
    /// 이번엔 안내하지 않습니다. 기록도 남기지 않아 다음에 다시 판단합니다.
    case skip
    /// 안내할 것이 없어 이 버전을 판단한 것으로만 남깁니다. 업데이트 후 첫 진입에서만 씁니다.
    case markJudged
    /// 이 종류로 안내합니다.
    case guide(NotificationGuideKind)

    /// 경로별로 다시 안내하기까지 기다리는 날 수입니다. 그 경로에서 안내한 날부터 7일이 지나야 다시 안내합니다.
    static let pathRepeatDays = 7

    /// 오늘 다른 자동 안내를 띄웠는지, 이 버전을 판단했는지를 먼저 보고, 그다음 상태에 맞는 안내 종류를 고릅니다.
    static func updateEntry(
        record: NotificationGuideRecord,
        today: KSTDay,
        appVersion: String,
        permission: NotificationPermission,
        isMarketingAgreed: Bool
    ) -> Self {
        guard record.lastAutomaticGuideDay != today else { return .skip }
        guard record.updateEntryJudgedVersion != appVersion else { return .skip }
        guard let kind = NotificationGuideKind(permission: permission, isMarketingAgreed: isMarketingAgreed) else {
            return .markJudged
        }
        return .guide(kind)
    }

    /// 지점 상세에 들어왔을 때의 안내를 정합니다.
    ///
    /// 오늘 다른 자동 안내를 띄웠는지, 이 경로에서 7일 안에 안내했는지를 먼저 보고, 그다음 상태에 맞는 안내 종류를 고릅니다.
    /// 알림이 켜져 있고 동의도 했으면 안내하지 않고 기록도 남기지 않습니다.
    static func photoBoothDetail(
        record: NotificationGuideRecord,
        today: KSTDay,
        permission: NotificationPermission,
        isMarketingAgreed: Bool
    ) -> Self {
        guard record.lastAutomaticGuideDay != today else { return .skip }
        if let guidedDay = record.photoBoothDetailGuidedDay, today.days(since: guidedDay) < pathRepeatDays {
            return .skip
        }
        guard let kind = NotificationGuideKind(permission: permission, isMarketingAgreed: isMarketingAgreed) else {
            return .skip
        }
        return .guide(kind)
    }
}
