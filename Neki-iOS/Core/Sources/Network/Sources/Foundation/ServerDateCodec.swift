//
//  ServerDateCodec.swift
//  Neki-iOS
//
//  Created by SwainYun on 11/6/26.
//

import Foundation

/// 서버로 내보내는 날짜 문자열의 계약입니다.
///
/// 읽기 호환 형식은 `ServerDateCodec` 내부에서만 판별합니다. 호출부가 과거 형식을
/// 새 요청에 선택하지 못하도록 서버가 현재 허용하는 출력 형식만 공개합니다.
enum ServerDateFormat: Equatable, Sendable {
    /// 일반 API의 `LocalDateTime`: KST, 초 단위, 오프셋 없음
    case kstLocalSeconds
    /// 행동 로그의 `Instant`: UTC, 밀리초 세 자리, `Z` 포함
    case utcMilliseconds
}

enum ServerDateCodecError: Error, Equatable, Sendable {
    case invalidValue
}

/// 서버 날짜 계약을 한 곳에서 파싱하고 직렬화합니다.
///
/// 포맷 전략은 값 타입으로 한 번 구성해 재사용합니다. 입력 문자열을 캐시하지 않으므로
/// 목록 크기에 따라 메모리가 증가하지 않으며 여러 Task에서 동시에 사용할 수 있습니다.
struct ServerDateCodec: Sendable {
    private static let locale = Locale(identifier: "en_US_POSIX")
    private static let calendar = Calendar(identifier: .gregorian)
    private static let koreaTimeZone = TimeZone(identifier: "Asia/Seoul")!

    private static let kstLocalSecondsStyle = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)T\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
        locale: locale,
        timeZone: koreaTimeZone,
        calendar: calendar
    )

    private static let kstLocalFractionalStyle = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)T\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(9))",
        locale: locale,
        timeZone: koreaTimeZone,
        calendar: calendar
    )

    private static let iso8601SecondsStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let iso8601FractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    func decode(_ value: String) throws -> Date {
        let containsFractionalSeconds = value.utf8.contains(UInt8(ascii: "."))
        let containsExplicitTimeZone = Self.containsExplicitTimeZone(value)

        do {
            switch (containsExplicitTimeZone, containsFractionalSeconds) {
            case (true, true):
                return try Self.iso8601FractionalStyle.parseStrategy.parse(value)
            case (true, false):
                return try Self.iso8601SecondsStyle.parseStrategy.parse(value)
            case (false, true):
                return try Self.kstLocalFractionalStyle.parseStrategy.parse(value)
            case (false, false):
                return try Self.kstLocalSecondsStyle.parseStrategy.parse(value)
            }
        } catch {
            throw ServerDateCodecError.invalidValue
        }
    }

    func encode(_ date: Date, as format: ServerDateFormat) -> String {
        switch format {
        case .kstLocalSeconds:
            return Self.kstLocalSecondsStyle.format(date)
        case .utcMilliseconds:
            return encodeUTC(millisecondsSince1970: Int64(date.timeIntervalSince1970 * 1_000))
        }
    }

    /// 이미 정수 밀리초로 보관된 로그 시각의 정밀도를 부동소수점 변환 없이 유지합니다.
    func encodeUTC(millisecondsSince1970 milliseconds: Int64) -> String {
        let seconds = milliseconds / 1_000
        let remainder = milliseconds % 1_000
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        let secondsText = Self.iso8601SecondsStyle.format(date)
        return String(secondsText.dropLast()) + String(format: ".%03lldZ", remainder)
    }
}

extension ServerDateCodec {
    static var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        let codec = ServerDateCodec()
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            do {
                return try codec.decode(value)
            } catch {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "The server date does not match a supported contract."
                )
            }
        }
    }
}

private extension ServerDateCodec {
    static func containsExplicitTimeZone(_ value: String) -> Bool {
        guard value.count > 10 else { return false }
        let timeAndZone = value.dropFirst(10)
        return timeAndZone.last == "Z"
            || timeAndZone.last == "z"
            || timeAndZone.contains("+")
            || timeAndZone.contains("-")
    }
}
