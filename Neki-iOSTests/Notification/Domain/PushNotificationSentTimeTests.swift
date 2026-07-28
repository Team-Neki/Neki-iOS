//
//  PushNotificationSentTimeTests.swift
//  Neki-iOSTests
//
//  Created by Codex on 7/23/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct PushNotificationSentTimeTests {
    @Test("발송 후 경과시간을 임시 상대시간 정책에 맞게 표시한다")
    func relativeValue_usesDisplayPolicyBoundaries() {
        let referenceDate = Date(timeIntervalSince1970: 100_000)

        #expect(makeSentTime(secondsAgo: 59, from: referenceDate).relativeValue(to: referenceDate) == .justNow)
        #expect(makeSentTime(secondsAgo: 60, from: referenceDate).relativeValue(to: referenceDate) == .minutes(1))
        #expect(makeSentTime(secondsAgo: 3_599, from: referenceDate).relativeValue(to: referenceDate) == .minutes(59))
        #expect(makeSentTime(secondsAgo: 3_600, from: referenceDate).relativeValue(to: referenceDate) == .hours(1))
        #expect(makeSentTime(secondsAgo: 86_399, from: referenceDate).relativeValue(to: referenceDate) == .hours(23))
        #expect(makeSentTime(secondsAgo: 86_400, from: referenceDate).relativeValue(to: referenceDate) == .days(1))
        #expect(makeSentTime(secondsAgo: 2_592_000, from: referenceDate).relativeValue(to: referenceDate) == .months(1))
        #expect(makeSentTime(secondsAgo: 31_535_999, from: referenceDate).relativeValue(to: referenceDate) == .months(12))
        #expect(makeSentTime(secondsAgo: 31_536_000, from: referenceDate).relativeValue(to: referenceDate) == .years(1))
    }

    @Test("현재 표시 단위가 변경되는 다음 경계 시각을 계산한다")
    func nextRelativeValueUpdateDate_returnsNextDisplayBoundary() {
        let sentDate = Date(timeIntervalSince1970: 100_000)

        #expect(
            PushNotificationSentTime(value: sentDate)
                .nextRelativeValueUpdateDate(after: sentDate.addingTimeInterval(70))
            == sentDate.addingTimeInterval(120)
        )
        #expect(
            PushNotificationSentTime(value: sentDate)
                .nextRelativeValueUpdateDate(after: sentDate.addingTimeInterval(3_700))
            == sentDate.addingTimeInterval(7_200)
        )
        #expect(
            PushNotificationSentTime(value: sentDate)
                .nextRelativeValueUpdateDate(after: sentDate.addingTimeInterval(31_104_000))
            == sentDate.addingTimeInterval(31_536_000)
        )
    }
}

private extension PushNotificationSentTimeTests {
    func makeSentTime(secondsAgo: TimeInterval, from referenceDate: Date) -> PushNotificationSentTime {
        PushNotificationSentTime(value: referenceDate.addingTimeInterval(-secondsAgo))
    }
}
