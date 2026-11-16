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
    private let today = KSTDay(year: 2026, month: 11, day: 10)
    private let yesterday = KSTDay(year: 2026, month: 11, day: 9)
    private let version = "1.4.1"

    @Test("오늘 자동 안내를 띄웠으면 이 버전을 판단하지 않았어도 넘긴다")
    func updateEntry_guideShownToday_skips() {
        let record = NotificationGuideRecord(lastAutomaticGuideDay: today, updateEntryJudgedVersion: "1.4.0")

        #expect(decide(record) == .skip)
    }

    @Test("이 버전을 이미 판단했으면 넘긴다")
    func updateEntry_versionJudged_skips() {
        let record = NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: version)

        #expect(decide(record) == .skip)
    }

    @Test("띄울 모달이 없으면 이 버전을 판단한 것으로만 남긴다")
    func updateEntry_noModal_marksJudged() {
        #expect(decide(NotificationGuideRecord(), permission: .enabled, isMarketingAgreed: true) == .markJudged)
    }

    @Test("새 버전이면 상태에 맞는 모달을 띄운다")
    func updateEntry_newVersion_presentsModal() {
        let record = NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: "1.4.0")

        #expect(decide(record, permission: .requestable, isMarketingAgreed: false) == .guide(.consentAndEnable))
    }

    @Test("넘기면 기록을 바꾸지 않는다")
    func apply_skip_keepsRecord() {
        let original = NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: "1.4.0")
        var record = original

        record.applyUpdateEntry(.skip, today: today, appVersion: version)

        #expect(record == original)
    }

    @Test("판단만 하면 버전만 남긴다")
    func apply_markJudged_recordsVersionOnly() {
        var record = NotificationGuideRecord(lastAutomaticGuideDay: yesterday)

        record.applyUpdateEntry(.markJudged, today: today, appVersion: version)

        #expect(record == NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: version))
    }

    @Test("모달을 띄우면 버전과 오늘 날짜를 남긴다")
    func apply_present_recordsVersionAndDay() {
        var record = NotificationGuideRecord()

        record.applyUpdateEntry(.guide(.consentOnly), today: today, appVersion: version)

        #expect(record == NotificationGuideRecord(lastAutomaticGuideDay: today, updateEntryJudgedVersion: version))
    }

    @Test("저장했다가 다시 읽어도 같은 기록이다", arguments: [
        NotificationGuideRecord(),
        NotificationGuideRecord(lastAutomaticGuideDay: KSTDay(year: 2026, month: 11, day: 10), updateEntryJudgedVersion: "1.4.1"),
        NotificationGuideRecord(
            lastAutomaticGuideDay: KSTDay(year: 2026, month: 11, day: 10),
            updateEntryJudgedVersion: "1.4.1",
            photoBoothDetailGuidedDay: KSTDay(year: 2026, month: 11, day: 10)
        )
    ])
    func codable_roundTrip_keepsRecord(record: NotificationGuideRecord) throws {
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(NotificationGuideRecord.self, from: data)

        #expect(decoded == record)
    }

    @Test("지점 상세 날짜가 없던 기록도 읽는다")
    func decode_withoutPhotoBoothDetailDay_readsRecord() throws {
        let data = Data(#"{"lastAutomaticGuideDay":{"year":2026,"month":11,"day":9},"updateEntryJudgedVersion":"1.4.1"}"#.utf8)

        let decoded = try JSONDecoder().decode(NotificationGuideRecord.self, from: data)

        #expect(decoded == NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: version))
    }

    // MARK: - 지점 상세 진입

    @Test("지점 상세에 들어와도 오늘 다른 자동 안내를 띄웠으면 넘긴다")
    func photoBoothDetail_guideShownToday_skips() {
        let record = NotificationGuideRecord(lastAutomaticGuideDay: today)

        #expect(decidePhotoBoothDetail(record) == .skip)
    }

    @Test(
        "지점 상세에서 안내한 날부터 7일 안이면 넘기고, 7일이 지나면 다시 안내한다",
        arguments: [
            (KSTDay(year: 2026, month: 11, day: 4), NotificationGuideDecision.skip),
            (KSTDay(year: 2026, month: 11, day: 3), .guide(.consentAndEnable))
        ]
    )
    func photoBoothDetail_pathRepeat_waitsSevenDays(guidedDay: KSTDay, expected: NotificationGuideDecision) {
        let record = NotificationGuideRecord(lastAutomaticGuideDay: guidedDay, photoBoothDetailGuidedDay: guidedDay)

        #expect(decidePhotoBoothDetail(record, permission: .requestable, isMarketingAgreed: false) == expected)
    }

    @Test("지점 상세는 업데이트 후 첫 진입을 판단한 버전과 상관없이 상태에 맞게 안내한다")
    func photoBoothDetail_judgedVersion_stillGuides() {
        let record = NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: version)

        #expect(decidePhotoBoothDetail(record, permission: .enabled, isMarketingAgreed: false) == .guide(.consentOnly))
    }

    @Test("지점 상세에 들어와도 알림이 켜져 있고 동의도 했으면 안내하지 않는다")
    func photoBoothDetail_enabledAndAgreed_skips() {
        #expect(decidePhotoBoothDetail(NotificationGuideRecord(), permission: .enabled, isMarketingAgreed: true) == .skip)
    }

    @Test("지점 상세에서 안내하면 오늘 날짜를 하루 한 번 기록과 이 경로 기록에 함께 남긴다")
    func applyPhotoBoothDetail_guide_recordsDays() {
        var record = NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: version)

        record.applyPhotoBoothDetail(.guide(.consentOnly), today: today)

        #expect(record == NotificationGuideRecord(
            lastAutomaticGuideDay: today,
            updateEntryJudgedVersion: version,
            photoBoothDetailGuidedDay: today
        ))
    }

    @Test("지점 상세에서 안내하지 않으면 기록을 바꾸지 않는다")
    func applyPhotoBoothDetail_skip_keepsRecord() {
        let original = NotificationGuideRecord(lastAutomaticGuideDay: yesterday, photoBoothDetailGuidedDay: yesterday)
        var record = original

        record.applyPhotoBoothDetail(.skip, today: today)

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
            today: today,
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
            today: today,
            permission: permission,
            isMarketingAgreed: isMarketingAgreed
        )
    }
}
