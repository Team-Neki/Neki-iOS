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
        return DateFormatters.dotFormat.string(from: self)
    }
}

private struct DateFormatters {
    static let dotFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
}
