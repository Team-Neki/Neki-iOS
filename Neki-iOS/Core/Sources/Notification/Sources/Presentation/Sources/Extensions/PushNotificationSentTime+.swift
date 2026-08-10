//
//  PushNotificationSentTime+.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/23/26.
//

extension PushNotificationSentTime.RelativeValue {
    var displayText: String {
        switch self {
        case .justNow: return "방금 전"
        case let .minutes(value): return "\(value)분 전"
        case let .hours(value): return "\(value)시간 전"
        case let .days(value): return "\(value)일 전"
        case let .months(value): return "\(value)개월 전"
        case let .years(value): return "\(value)년 전"
        }
    }
}
