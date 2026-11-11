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

        #expect(decide(record, permission: .requestable, isMarketingAgreed: false) == .present(.consentAndEnable))
    }

    @Test("넘기면 기록을 바꾸지 않는다")
    func apply_skip_keepsRecord() {
        let original = NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: "1.4.0")
        var record = original

        record.apply(.skip, today: today, appVersion: version)

        #expect(record == original)
    }

    @Test("판단만 하면 버전만 남긴다")
    func apply_markJudged_recordsVersionOnly() {
        var record = NotificationGuideRecord(lastAutomaticGuideDay: yesterday)

        record.apply(.markJudged, today: today, appVersion: version)

        #expect(record == NotificationGuideRecord(lastAutomaticGuideDay: yesterday, updateEntryJudgedVersion: version))
    }

    @Test("모달을 띄우면 버전과 오늘 날짜를 남긴다")
    func apply_present_recordsVersionAndDay() {
        var record = NotificationGuideRecord()

        record.apply(.present(.consentOnly), today: today, appVersion: version)

        #expect(record == NotificationGuideRecord(lastAutomaticGuideDay: today, updateEntryJudgedVersion: version))
    }

    @Test("저장했다가 다시 읽어도 같은 기록이다", arguments: [
        NotificationGuideRecord(),
        NotificationGuideRecord(lastAutomaticGuideDay: KSTDay(year: 2026, month: 11, day: 10), updateEntryJudgedVersion: "1.4.1")
    ])
    func codable_roundTrip_keepsRecord(record: NotificationGuideRecord) throws {
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(NotificationGuideRecord.self, from: data)

        #expect(decoded == record)
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
}
