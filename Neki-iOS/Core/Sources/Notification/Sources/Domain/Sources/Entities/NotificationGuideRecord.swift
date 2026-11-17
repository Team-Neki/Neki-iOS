//
//  NotificationGuideRecord.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation

/// 자동 알림 안내를 언제 띄웠고 어느 앱 버전에서 판단했는지 사용자별로 남긴 기록입니다.
struct NotificationGuideRecord: Codable, Equatable, Sendable {
    /// 마지막으로 자동 안내를 띄운 시각입니다. 자동 안내는 경로와 상관없이 이 시각부터 하루가 지나야 다시 띄웁니다.
    var lastAutomaticGuidedAt: Date?
    /// 업데이트 후 첫 진입 안내를 판단한 앱 버전입니다. 버전마다 한 번만 판단합니다.
    var updateEntryJudgedVersion: String?
    /// 지점 상세 진입에서 마지막으로 안내한 시각입니다. 이 경로는 안내한 때부터 7일이 지나야 다시 안내합니다.
    var photoBoothDetailGuidedAt: Date?

    init(
        lastAutomaticGuidedAt: Date? = nil,
        updateEntryJudgedVersion: String? = nil,
        photoBoothDetailGuidedAt: Date? = nil
    ) {
        self.lastAutomaticGuidedAt = lastAutomaticGuidedAt
        self.updateEntryJudgedVersion = updateEntryJudgedVersion
        self.photoBoothDetailGuidedAt = photoBoothDetailGuidedAt
    }

    /// 사용자별 기록을 저장하는 키입니다.
    static func storageKey(userID: Int) -> String {
        "NotificationGuideRecord_\(userID)"
    }

    /// 업데이트 후 첫 진입의 판단 결과를 기록에 남깁니다.
    ///
    /// 안내할 때 버전과 시각을 함께 남기므로, 취소·OS 거부·설정에서 켜지 않음은 모두 다음 버전까지 다시 띄우지 않습니다.
    mutating func applyUpdateEntry(_ decision: NotificationGuideDecision, now: Date, appVersion: String) {
        switch decision {
        case .skip:
            return
        case .markJudged:
            updateEntryJudgedVersion = appVersion
        case .guide:
            updateEntryJudgedVersion = appVersion
            lastAutomaticGuidedAt = now
        }
    }

    /// 지점 상세 진입의 판단 결과를 기록에 남깁니다.
    ///
    /// 안내할 때 이 경로의 시각도 함께 남기므로, 취소·OS 거부·설정에서 켜지 않음은 모두 7일 뒤에 다시 안내합니다.
    mutating func applyPhotoBoothDetail(_ decision: NotificationGuideDecision, now: Date) {
        guard case .guide = decision else { return }
        lastAutomaticGuidedAt = now
        photoBoothDetailGuidedAt = now
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

    /// 자동 안내 사이에 기다리는 시간입니다. 경로와 상관없이 마지막 자동 안내로부터 하루가 지나야 다시 안내합니다.
    static let automaticGuideInterval: TimeInterval = 60 * 60 * 24
    /// 경로별로 다시 안내하기까지 기다리는 시간입니다. 그 경로에서 안내한 때부터 7일이 지나야 다시 안내합니다.
    static let pathRepeatInterval: TimeInterval = 60 * 60 * 24 * 7

    /// 하루 안에 다른 자동 안내를 띄웠는지, 이 버전을 판단했는지를 먼저 보고, 그다음 상태에 맞는 안내 종류를 고릅니다.
    static func updateEntry(
        record: NotificationGuideRecord,
        now: Date,
        appVersion: String,
        permission: NotificationPermission,
        isMarketingAgreed: Bool
    ) -> Self {
        guard hasElapsed(automaticGuideInterval, since: record.lastAutomaticGuidedAt, now: now) else { return .skip }
        guard record.updateEntryJudgedVersion != appVersion else { return .skip }
        guard let kind = NotificationGuideKind(permission: permission, isMarketingAgreed: isMarketingAgreed) else {
            return .markJudged
        }
        return .guide(kind)
    }

    /// 지점 상세에 들어왔을 때의 안내를 정합니다.
    ///
    /// 하루 안에 다른 자동 안내를 띄웠는지, 이 경로에서 안내한 지 7일이 지났는지를 먼저 보고, 그다음 상태에 맞는 안내 종류를 고릅니다.
    /// 알림이 켜져 있고 동의도 했으면 안내하지 않고 기록도 남기지 않습니다.
    static func photoBoothDetail(
        record: NotificationGuideRecord,
        now: Date,
        permission: NotificationPermission,
        isMarketingAgreed: Bool
    ) -> Self {
        guard hasElapsed(automaticGuideInterval, since: record.lastAutomaticGuidedAt, now: now) else { return .skip }
        guard hasElapsed(pathRepeatInterval, since: record.photoBoothDetailGuidedAt, now: now) else { return .skip }
        guard let kind = NotificationGuideKind(permission: permission, isMarketingAgreed: isMarketingAgreed) else {
            return .skip
        }
        return .guide(kind)
    }
}

private extension NotificationGuideDecision {
    /// 남긴 시각부터 `interval`이 지났는지입니다. 남긴 시각이 없으면 지난 것으로 봅니다.
    static func hasElapsed(_ interval: TimeInterval, since recordedAt: Date?, now: Date) -> Bool {
        guard let recordedAt else { return true }
        return now.timeIntervalSince(recordedAt) >= interval
    }
}
