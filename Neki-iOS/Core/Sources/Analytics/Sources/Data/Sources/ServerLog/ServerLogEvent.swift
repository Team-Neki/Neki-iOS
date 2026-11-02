//
//  ServerLogEvent.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation

/// 서버(`POST /api/logs`)로 보내는 행동 로그 한 건
/// - Note: 모든 값은 이벤트가 발생한 시점에 정하고, 재전송할 때도 바꾸지 않습니다.
struct ServerLogEvent: Equatable, Sendable {
    let eventID: String
    let eventType: String
    let eventProperties: [String: ServerLogValue]
    let occurredAtMilliseconds: Int64
    let sessionID: Int64
    let sequenceNumber: Int
    let deviceID: String
    let userIDAtOccurrence: String?
    let appVersion: String
    let context: [String: String]
}

extension ServerLogEvent {
    init(
        event: any AnalyticsEvent,
        occurrence: AnalyticsEventOccurrence,
        sessionID: Int64,
        sequenceNumber: Int,
        deviceID: String,
        userIDAtOccurrence: String?,
        context: ServerLogContext
    ) {
        self.init(
            eventID: occurrence.id,
            eventType: event.name.value,
            eventProperties: (event.parameters ?? [:]).reduce(into: [:]) { result, parameter in
                result[parameter.key.name] = ServerLogValue(parameter.value)
            },
            occurredAtMilliseconds: occurrence.occurredAtMilliseconds,
            sessionID: sessionID,
            sequenceNumber: sequenceNumber,
            deviceID: deviceID,
            userIDAtOccurrence: userIDAtOccurrence,
            appVersion: context.appVersion,
            context: context.values
        )
    }

    /// 저장과 전송에 쓰는 직렬화 결과
    /// - Note: 키를 정렬하므로 같은 로그는 언제 직렬화해도 같은 바이트가 됩니다.
    func encodedLog() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

extension ServerLogEvent: Encodable {
    private enum CodingKeys: String, CodingKey {
        case eventID = "eventId"
        case eventType
        case eventProperties
        case occurredAt
        case sessionID = "sessionId"
        case sequenceNumber
        case deviceID = "deviceId"
        case userIDAtOccurrence = "userIdAtOccurrence"
        case appVersion
        case context
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventID, forKey: .eventID)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(eventProperties, forKey: .eventProperties)
        try container.encode(ServerLogTimestamp.string(fromMilliseconds: occurredAtMilliseconds), forKey: .occurredAt)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(sequenceNumber, forKey: .sequenceNumber)
        try container.encode(deviceID, forKey: .deviceID)
        if let userIDAtOccurrence {
            try container.encode(userIDAtOccurrence, forKey: .userIDAtOccurrence)
        } else {
            try container.encodeNil(forKey: .userIDAtOccurrence)
        }
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(context, forKey: .context)
    }
}

/// JSON 타입을 유지해 보내는 이벤트 속성 값
enum ServerLogValue: Equatable, Sendable, Encodable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)

    init(_ value: AnalyticsParameterValue) {
        switch value {
        case let .string(value): self = .string(value)
        case let .integer(value): self = .integer(value)
        case let .double(value): self = .double(value)
        case let .boolean(value): self = .boolean(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .boolean(value): try container.encode(value)
        }
    }
}

enum ServerLogTimestamp {
    /// epoch milliseconds를 밀리초 세 자리까지 담은 UTC ISO 8601 문자열로 바꿉니다. 예: `2026-11-01T18:48:04.997Z`
    static func string(fromMilliseconds milliseconds: Int64) -> String {
        let (seconds, remainder) = milliseconds.quotientAndRemainder(dividingBy: 1000)
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        let secondsText = date.formatted(.iso8601)
        return String(secondsText.dropLast()) + String(format: ".%03lldZ", remainder)
    }
}
