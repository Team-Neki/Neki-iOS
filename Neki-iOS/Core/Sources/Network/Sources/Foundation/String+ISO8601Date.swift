//
//  String+ISO8601Date.swift
//  Neki-iOS
//
//  Created by Codex on 6/22/26.
//

import Foundation

extension String {
    func toISO8601DateOrNil() -> Date? {
        if let date = ISO8601DateFormatters.fractionalWithTimeZone.date(from: self) {
            return date
        }

        if let date = ISO8601DateFormatters.fractionalWithoutTimeZone.date(from: self) {
            return date
        }

        if let date = ISO8601DateFormatters.defaultWithTimeZone.date(from: self) {
            return date
        }

        return ISO8601DateFormatters.defaultWithoutTimeZone.date(from: self)
    }
}

private enum ISO8601DateFormatters {
    static let fractionalWithTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let fractionalWithoutTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withYear, .withMonth, .withDay,
            .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    static let defaultWithTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let defaultWithoutTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withYear, .withMonth, .withDay,
            .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime
        ]
        return formatter
    }()
}
