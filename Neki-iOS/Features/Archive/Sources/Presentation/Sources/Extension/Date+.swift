//
//  Date+.swift
//  Neki-iOS
//
//  Created by OneTen on 4/2/26.
//

import Foundation

extension Date {
    /// Date를 "yyyy.MM.dd" 형태의 문자열로 변환합니다.
    func toDotFormatString() -> String {
        ArchiveDateDisplayStyle.day.string(from: self)
    }
}

private enum ArchiveDateDisplayStyle {
    case day

    private static let dayStyle = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits).\(month: .twoDigits).\(day: .twoDigits)",
        locale: Locale(identifier: "ko_KR"),
        timeZone: .autoupdatingCurrent,
        calendar: Calendar(identifier: .gregorian)
    )

    func string(from date: Date) -> String {
        switch self {
        case .day: Self.dayStyle.format(date)
        }
    }
}
