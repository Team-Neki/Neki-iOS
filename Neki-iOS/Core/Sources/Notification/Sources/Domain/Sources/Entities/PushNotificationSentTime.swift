//
//  PushNotificationSentTime.swift
//  Neki-iOS
//
//  Created by Codex on 7/23/26.
//

import Foundation

public struct PushNotificationSentTime: Equatable, Sendable {
    public enum RelativeValue: Equatable, Sendable {
        case justNow
        case minutes(Int)
        case hours(Int)
        case days(Int)
        case months(Int)
        case years(Int)
    }

    private enum TimeInterval {
        static let minute: Foundation.TimeInterval = 60
        static let hour: Foundation.TimeInterval = minute * 60
        static let day: Foundation.TimeInterval = hour * 24
        static let month: Foundation.TimeInterval = day * 30
        static let year: Foundation.TimeInterval = day * 365
    }

    public let value: Date

    public init(value: Date) {
        self.value = value
    }

    public func relativeValue(to referenceDate: Date = .now) -> RelativeValue {
        let elapsedTime = referenceDate.timeIntervalSince(value)
        guard elapsedTime >= TimeInterval.minute else { return .justNow }
        guard elapsedTime >= TimeInterval.hour else { return .minutes(Int(elapsedTime / TimeInterval.minute)) }
        guard elapsedTime >= TimeInterval.day else { return .hours(Int(elapsedTime / TimeInterval.hour)) }
        guard elapsedTime >= TimeInterval.month else { return .days(Int(elapsedTime / TimeInterval.day)) }
        guard elapsedTime >= TimeInterval.year else { return .months(Int(elapsedTime / TimeInterval.month)) }
        return .years(Int(elapsedTime / TimeInterval.year))
    }
}
