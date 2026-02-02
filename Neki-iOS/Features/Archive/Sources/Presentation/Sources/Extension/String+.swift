//
//  String+.swift
//  Neki-iOS
//
//  Created by OneTen on 2/2/26.
//

import Foundation
import os

extension String {
    func toISO8601Date() -> Date {
        // 1. 소수점 초(.123456) + 타임존(Z) 포함 (예: 2026-01-25T20:21:43.853835Z)
        if let date = DateFormatters.iso8601Fractional.date(from: self) {
            return date
        }
        
        // 2. 소수점 초 포함 + 타임존 없음 (예: 2026-01-25T20:21:43.853835)
        if let date = DateFormatters.iso8601FractionalNoTimeZone.date(from: self) {
            return date
        }
        
        // 3. 일반 포맷 + 타임존(Z) (예: 2026-01-25T20:21:43Z)
        if let date = DateFormatters.iso8601.date(from: self) {
            return date
        }
        
        // 4. 일반 포맷 + 타임존 없음 (예: 2026-01-29T12:54:45)
        if let date = DateFormatters.iso8601NoTimeZone.date(from: self) {
            return date
        }
        
        Logger.presentation.error("⚠️ Date Parsing Failed: \(self)")
        return Date()
    }
}

private struct DateFormatters {
    
    // 1. 밀리초 + 타임존 (Standard InternetDateTime + Fractional)
    static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // 2. 밀리초 + 타임존 없음
    static let iso8601FractionalNoTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withYear, .withMonth, .withDay,
            .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime,
            .withFractionalSeconds
        ]
        return formatter
    }()
    
    // 3. 일반 + 타임존 (Standard InternetDateTime)
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // 4. 일반 + 타임존 없음
    static let iso8601NoTimeZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withYear, .withMonth, .withDay,
            .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime
        ]
        return formatter
    }()
}
