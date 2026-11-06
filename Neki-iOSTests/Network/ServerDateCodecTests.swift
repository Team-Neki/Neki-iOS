//
//  ServerDateCodecTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 11/6/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerDateCodecTests {
    private let codec = ServerDateCodec()

    @Test(
        "지원하는 서버 날짜 문자열을 절대 시각으로 변환한다",
        arguments: [
            ("2025-12-23T16:09:00", 1_766_473_740.0),
            ("2025-12-23T16:09:00.123456", 1_766_473_740.123456),
            ("2025-12-23T07:09:00Z", 1_766_473_740.0),
            ("2025-12-23T16:09:00+09:00", 1_766_473_740.0),
            ("2025-12-23T07:09:00.123456Z", 1_766_473_740.123456)
        ]
    )
    func decode_supportedContracts(value: String, expectedTimeInterval: TimeInterval) throws {
        let date = try codec.decode(value)

        // Foundation's locale-based no-offset parser normalizes fractional input to milliseconds.
        #expect(abs(date.timeIntervalSince1970 - expectedTimeInterval) < 0.001)
    }

    @Test("KST 무오프셋 형식은 기기 기본 시간대와 무관한 문자열을 만든다")
    func encode_kstLocalSeconds() {
        let date = Date(timeIntervalSince1970: 1_766_473_740)

        #expect(codec.encode(date, as: .kstLocalSeconds) == "2025-12-23T16:09:00")
    }

    @Test(
        "UTC 로그 형식은 정수 밀리초를 정확히 보존한다",
        arguments: zip(
            [Int64(0), 1_793_610_697_007, 1_793_558_884_997],
            ["1970-01-01T00:00:00.000Z", "2026-11-02T09:11:37.007Z", "2026-11-01T18:48:04.997Z"]
        )
    )
    func encodeUTC_preservesIntegerMilliseconds(milliseconds: Int64, expected: String) {
        #expect(codec.encodeUTC(millisecondsSince1970: milliseconds) == expected)
    }

    @Test("지원하지 않는 문자열은 원문을 노출하지 않는 오류로 실패한다")
    func decode_invalidValue() {
        #expect(throws: ServerDateCodecError.invalidValue) {
            try codec.decode("not-a-date")
        }
    }

    @Test("값 타입 codec은 여러 Task에서 같은 결과를 만든다")
    func decode_isSafeForConcurrentUse() async throws {
        let value = "2025-12-23T16:09:00"
        let expected = try codec.decode(value)

        let results = try await withThrowingTaskGroup(of: Date.self) { group in
            for _ in 0..<100 {
                group.addTask { try codec.decode(value) }
            }

            var values: [Date] = []
            for try await date in group {
                values.append(date)
            }
            return values
        }

        #expect(results.count == 100)
        #expect(results.allSatisfy { $0 == expected })
    }
}
