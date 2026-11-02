//
//  ServerLogEventTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerLogEventTests {
    @Test("계약의 필드를 이름과 JSON 타입 그대로 담는다")
    func encodedLog_matchesContractFieldsAndTypes() throws {
        let log = makeLog(
            properties: [
                "count": .integer(3),
                "method": .string("camera"),
                "has_filter": .boolean(true),
                "ratio": .double(0.5)
            ],
            userID: "123"
        )

        let json = String(decoding: try log.encodedLog(), as: UTF8.self)

        #expect(json == #"{"appVersion":"1.2.9","context":{"device_model":"iPhone17,1","os_name":"ios"},"deviceId":"device-1","eventId":"3fa85f64-5717-4562-b3fc-2c963f66afa6","eventProperties":{"count":3,"has_filter":true,"method":"camera","ratio":0.5},"eventType":"photo_upload","occurredAt":"2026-11-01T18:48:04.997Z","sequenceNumber":2,"sessionId":1793558880000,"userIdAtOccurrence":"123"}"#)
    }

    @Test("로그아웃 상태에서 남긴 로그는 userIdAtOccurrence를 null로 보낸다")
    func encodedLog_whenSignedOut_sendsNullUserID() throws {
        let json = String(decoding: try makeLog(userID: nil).encodedLog(), as: UTF8.self)

        #expect(json.contains(#""userIdAtOccurrence":null"#))
    }

    @Test("같은 로그는 다시 직렬화해도 같은 바이트다")
    func encodedLog_isStable() throws {
        let properties: [String: ServerLogValue] = (1...20).reduce(into: [:]) { result, index in
            result["key_\(index)"] = .integer(index)
        }
        let log = makeLog(properties: properties)

        #expect(try log.encodedLog() == log.encodedLog())
    }

    @Test("이벤트의 속성과 발생 정보, 문맥을 그대로 옮긴다")
    func init_mapsEventOccurrenceAndContext() {
        let occurrence = AnalyticsEventOccurrence(
            id: UUID(uuidString: "3FA85F64-5717-4562-B3FC-2C963F66AFA6")!,
            occurredAt: Date(timeIntervalSince1970: 1_793_610_697.25)
        )
        let context = ServerLogContext(appVersion: "1.2.9", values: ["os_name": "ios"])

        let log = ServerLogEvent(
            event: ParameterEventStub(),
            occurrence: occurrence,
            sessionID: 1_793_610_697_000,
            sequenceNumber: 4,
            deviceID: "device-1",
            userIDAtOccurrence: "123",
            context: context
        )

        #expect(log.eventID == "3fa85f64-5717-4562-b3fc-2c963f66afa6")
        #expect(log.eventType == "photo_upload")
        #expect(log.eventProperties == [
            "count": .integer(3),
            "method": .string("camera"),
            "has_filter": .boolean(false),
            "page": .double(1.5)
        ])
        #expect(log.occurredAtMilliseconds == 1_793_610_697_250)
        #expect(log.sessionID == 1_793_610_697_000)
        #expect(log.sequenceNumber == 4)
        #expect(log.appVersion == "1.2.9")
        #expect(log.context == ["os_name": "ios"])
    }

    @Test("속성이 없는 이벤트는 eventProperties를 빈 객체로 보낸다")
    func init_withoutParameters_sendsEmptyObject() throws {
        let log = ServerLogEvent(
            event: AnalyticsEventStub.appOpen,
            occurrence: AnalyticsEventOccurrence(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                occurredAt: Date(timeIntervalSince1970: 0)
            ),
            sessionID: 0,
            sequenceNumber: 1,
            deviceID: "device-1",
            userIDAtOccurrence: nil,
            context: ServerLogContext(appVersion: "1.2.9", values: [:])
        )

        let json = String(decoding: try log.encodedLog(), as: UTF8.self)

        #expect(json.contains(#""eventProperties":{}"#))
    }

    @Test(
        "발생 시각은 밀리초 세 자리를 붙인 UTC ISO 8601 문자열로 쓴다",
        arguments: zip(
            [Int64(0), 1_793_610_697_007, 1_793_558_884_997],
            ["1970-01-01T00:00:00.000Z", "2026-11-02T09:11:37.007Z", "2026-11-01T18:48:04.997Z"]
        )
    )
    func timestamp_keepsMilliseconds(milliseconds: Int64, expected: String) {
        #expect(ServerLogTimestamp.string(fromMilliseconds: milliseconds) == expected)
    }
}


// MARK: - Helpers

private extension ServerLogEventTests {
    struct ParameterEventStub: AnalyticsEvent {
        var name: AnalyticsEventName { .photoUpload }
        var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
            [.count: .integer(3), .method: .string("camera"), .hasFilter: .boolean(false), .page: .double(1.5)]
        }
    }

    func makeLog(properties: [String: ServerLogValue] = [:], userID: String? = "123") -> ServerLogEvent {
        ServerLogEvent(
            eventID: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            eventType: "photo_upload",
            eventProperties: properties,
            occurredAtMilliseconds: 1_793_558_884_997,
            sessionID: 1_793_558_880_000,
            sequenceNumber: 2,
            deviceID: "device-1",
            userIDAtOccurrence: userID,
            appVersion: "1.2.9",
            context: ["device_model": "iPhone17,1", "os_name": "ios"]
        )
    }
}
