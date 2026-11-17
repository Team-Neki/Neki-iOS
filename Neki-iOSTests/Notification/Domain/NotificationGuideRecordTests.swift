//
//  NotificationGuideRecordTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct NotificationGuideRecordTests {
    private let version = "1.4.1"
    /// 2026-11-10 10:00 한국 시간
    private let now = Date(timeIntervalSince1970: 1_794_272_400)
    /// 마지막 자동 안내로부터 하루가 넘게 지난 시각입니다.
    private var twoDaysAgo: Date { now.addingTimeInterval(-2 * 86_400) }

    @Test(
        "마지막 자동 안내로부터 하루가 지나지 않았으면 이 버전을 판단하지 않았어도 넘기고, 하루가 지나면 안내한다",
        arguments: [
            (-(86_400 - 1), NotificationGuideDecision.skip),
            (-86_400, .guide(.enableNotifications))
        ] as [(TimeInterval, NotificationGuideDecision)]
    )
    func updateEntry_automaticGuideInterval_waitsOneDay(offset: TimeInterval, expected: NotificationGuideDecision) {
        let record = NotificationGuideRecord(lastAutomaticGuidedAt: now.addingTimeInterval(offset), updateEntryJudgedVersion: "1.4.0")

        #expect(decide(record) == expected)
    }

    @Test("이 버전을 이미 판단했으면 넘긴다")
    func updateEntry_versionJudged_skips() {
        let record = NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo, updateEntryJudgedVersion: version)

        #expect(decide(record) == .skip)
    }

    @Test("띄울 모달이 없으면 이 버전을 판단한 것으로만 남긴다")
    func updateEntry_noModal_marksJudged() {
        #expect(decide(NotificationGuideRecord(), permission: .enabled, isMarketingAgreed: true) == .markJudged)
    }

    @Test("새 버전이면 상태에 맞는 모달을 띄운다")
    func updateEntry_newVersion_presentsModal() {
        let record = NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo, updateEntryJudgedVersion: "1.4.0")

        #expect(decide(record, permission: .requestable, isMarketingAgreed: false) == .guide(.consentAndEnable))
    }

    @Test("넘기면 기록을 바꾸지 않는다")
    func apply_skip_keepsRecord() {
        let original = NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo, updateEntryJudgedVersion: "1.4.0")
        var record = original

        record.applyUpdateEntry(.skip, now: now, appVersion: version)

        #expect(record == original)
    }

    @Test("판단만 하면 버전만 남긴다")
    func apply_markJudged_recordsVersionOnly() {
        var record = NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo)

        record.applyUpdateEntry(.markJudged, now: now, appVersion: version)

        #expect(record == NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo, updateEntryJudgedVersion: version))
    }

    @Test("모달을 띄우면 버전과 안내한 시각을 남긴다")
    func apply_present_recordsVersionAndTime() {
        var record = NotificationGuideRecord()

        record.applyUpdateEntry(.guide(.consentOnly), now: now, appVersion: version)

        #expect(record == NotificationGuideRecord(lastAutomaticGuidedAt: now, updateEntryJudgedVersion: version))
    }

    @Test("저장했다가 다시 읽어도 같은 기록이다", arguments: [
        NotificationGuideRecord(),
        NotificationGuideRecord(lastAutomaticGuidedAt: Date(timeIntervalSince1970: 1_794_272_400), updateEntryJudgedVersion: "1.4.1"),
        NotificationGuideRecord(
            lastAutomaticGuidedAt: Date(timeIntervalSince1970: 1_794_272_400),
            updateEntryJudgedVersion: "1.4.1",
            photoBoothDetailGuidedAt: Date(timeIntervalSince1970: 1_794_272_400)
        )
    ])
    func codable_roundTrip_keepsRecord(record: NotificationGuideRecord) throws {
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(NotificationGuideRecord.self, from: data)

        #expect(decoded == record)
    }

    @Test("저장된 기록에 없는 항목은 비워 두고 읽는다")
    func decode_missingFields_readsRecord() throws {
        let data = Data(#"{"updateEntryJudgedVersion":"1.4.1"}"#.utf8)

        let decoded = try JSONDecoder().decode(NotificationGuideRecord.self, from: data)

        #expect(decoded == NotificationGuideRecord(updateEntryJudgedVersion: version))
    }

    // MARK: - 지점 상세 진입

    @Test("지점 상세에 들어와도 하루 안에 다른 자동 안내를 띄웠으면 넘긴다")
    func photoBoothDetail_guideShownWithinOneDay_skips() {
        let record = NotificationGuideRecord(lastAutomaticGuidedAt: now.addingTimeInterval(-60 * 60))

        #expect(decidePhotoBoothDetail(record) == .skip)
    }

    @Test(
        "지점 상세에서 안내한 지 7일이 지나지 않았으면 넘기고, 7일이 지나면 다시 안내한다",
        arguments: [
            (-(7 * 86_400 - 1), NotificationGuideDecision.skip),
            (-7 * 86_400, .guide(.consentAndEnable))
        ] as [(TimeInterval, NotificationGuideDecision)]
    )
    func photoBoothDetail_pathRepeat_waitsSevenDays(offset: TimeInterval, expected: NotificationGuideDecision) {
        let guidedAt = now.addingTimeInterval(offset)
        let record = NotificationGuideRecord(lastAutomaticGuidedAt: guidedAt, photoBoothDetailGuidedAt: guidedAt)

        #expect(decidePhotoBoothDetail(record, permission: .requestable, isMarketingAgreed: false) == expected)
    }

    @Test("지점 상세는 업데이트 후 첫 진입을 판단한 버전과 상관없이 상태에 맞게 안내한다")
    func photoBoothDetail_judgedVersion_stillGuides() {
        let record = NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo, updateEntryJudgedVersion: version)

        #expect(decidePhotoBoothDetail(record, permission: .enabled, isMarketingAgreed: false) == .guide(.consentOnly))
    }

    @Test("지점 상세에 들어와도 알림이 켜져 있고 동의도 했으면 안내하지 않는다")
    func photoBoothDetail_enabledAndAgreed_skips() {
        #expect(decidePhotoBoothDetail(NotificationGuideRecord(), permission: .enabled, isMarketingAgreed: true) == .skip)
    }

    @Test("지점 상세에서 안내하면 하루 한 번 기록과 이 경로 기록에 안내한 시각을 남긴다")
    func applyPhotoBoothDetail_guide_recordsGuidedTime() {
        var record = NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo, updateEntryJudgedVersion: version)

        record.applyPhotoBoothDetail(.guide(.consentOnly), now: now)

        #expect(record == NotificationGuideRecord(
            lastAutomaticGuidedAt: now,
            updateEntryJudgedVersion: version,
            photoBoothDetailGuidedAt: now
        ))
    }

    @Test("지점 상세에서 안내하지 않으면 기록을 바꾸지 않는다")
    func applyPhotoBoothDetail_skip_keepsRecord() {
        let original = NotificationGuideRecord(lastAutomaticGuidedAt: twoDaysAgo, photoBoothDetailGuidedAt: twoDaysAgo)
        var record = original

        record.applyPhotoBoothDetail(.skip, now: now)

        #expect(record == original)
    }
}

private extension NotificationGuideRecordTests {
    func decide(
        _ record: NotificationGuideRecord,
        permission: NotificationPermission = .requestable,
        isMarketingAgreed: Bool = true
    ) -> NotificationGuideDecision {
        .updateEntry(
            record: record,
            now: now,
            appVersion: version,
            permission: permission,
            isMarketingAgreed: isMarketingAgreed
        )
    }

    func decidePhotoBoothDetail(
        _ record: NotificationGuideRecord,
        permission: NotificationPermission = .requestable,
        isMarketingAgreed: Bool = true
    ) -> NotificationGuideDecision {
        .photoBoothDetail(
            record: record,
            now: now,
            permission: permission,
            isMarketingAgreed: isMarketingAgreed
        )
    }
}
