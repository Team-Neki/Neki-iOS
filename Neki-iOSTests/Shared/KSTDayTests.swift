//
//  KSTDayTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct KSTDayTests {
    @Test("한국 시간 자정에 날짜가 바뀐다")
    func init_kstMidnight_changesDay() throws {
        let beforeMidnight = try makeDate("2026-11-09T14:59:59Z")
        let atMidnight = try makeDate("2026-11-09T15:00:00Z")

        #expect(beforeMidnight.kstDay == KSTDay(year: 2026, month: 11, day: 9))
        #expect(atMidnight.kstDay == KSTDay(year: 2026, month: 11, day: 10))
    }

    @Test("월과 일을 두 자리로 표시한다")
    func monthDayText_padsTwoDigits() {
        #expect(KSTDay(year: 2026, month: 3, day: 5).monthDayText == "03.05")
        #expect(KSTDay(year: 2026, month: 10, day: 20).monthDayText == "10.20")
    }

    @Test("저장했다가 다시 읽어도 같은 날짜다")
    func codable_roundTrip_keepsDay() throws {
        let day = KSTDay(year: 2026, month: 11, day: 10)

        let data = try JSONEncoder().encode(day)
        let decoded = try JSONDecoder().decode(KSTDay.self, from: data)

        #expect(decoded == day)
    }
}

private extension KSTDayTests {
    func makeDate(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }
}
