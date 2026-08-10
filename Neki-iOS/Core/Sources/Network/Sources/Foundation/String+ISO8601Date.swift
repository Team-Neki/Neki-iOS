//
//  String+ISO8601Date.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/22/26.
//

import Foundation

extension String {
    func toISO8601DateOrNil() -> Date? {
        if let date = ISO8601DateFormatters.fractionalWithTimeZone.date(from: self) {
            return date
        }

        if let date = ISO8601DateFormatters.fractionalWithoutTimeZoneInKST.date(from: self) {
            return date
        }

        if let date = ISO8601DateFormatters.defaultWithTimeZone.date(from: self) {
            return date
        }

        return ISO8601DateFormatters.defaultWithoutTimeZoneInKST.date(from: self)
    }
}

private enum ISO8601DateFormatters {
    static let fractionalWithTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let fractionalWithoutTimeZoneInKST: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withYear, .withMonth, .withDay,
            .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime,
            .withFractionalSeconds
        ]
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    static let defaultWithTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let defaultWithoutTimeZoneInKST: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withYear, .withMonth, .withDay,
            .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime
        ]
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
}
