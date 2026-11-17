//
//  Date+KST.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import Foundation

/// 한국 시간(Asia/Seoul) 기준 날짜입니다.
///
/// 이벤트·혜택 알림 동의 토스트처럼, 기기 시간대와 상관없이 한국 날짜를 보여 줄 때 씁니다.
struct KSTDay: Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date) {
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    /// "10.20"처럼 두 자리 월과 일을 점으로 이은 문자열입니다.
    var monthDayText: String {
        String(format: "%02d.%02d", month, day)
    }
}

extension Date {
    /// 이 시각이 속한 한국 시간 날짜입니다.
    var kstDay: KSTDay {
        KSTDay(self)
    }
}

private extension KSTDay {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()
}
