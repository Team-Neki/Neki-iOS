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

    public func nextRelativeValueUpdateDate(after referenceDate: Date) -> Date {
        let elapsedTime = max(referenceDate.timeIntervalSince(value), .zero)

        switch relativeValue(to: referenceDate) {
        case .justNow:
            return value.addingTimeInterval(TimeInterval.minute)
        case .minutes:
            return nextBoundaryDate(elapsedTime: elapsedTime, unit: TimeInterval.minute)
        case .hours:
            return nextBoundaryDate(elapsedTime: elapsedTime, unit: TimeInterval.hour)
        case .days:
            return nextBoundaryDate(elapsedTime: elapsedTime, unit: TimeInterval.day)
        case .months:
            return min(
                nextBoundaryDate(elapsedTime: elapsedTime, unit: TimeInterval.month),
                value.addingTimeInterval(TimeInterval.year)
            )
        case .years:
            return nextBoundaryDate(elapsedTime: elapsedTime, unit: TimeInterval.year)
        }
    }
}

private extension PushNotificationSentTime {
    func nextBoundaryDate(elapsedTime: Foundation.TimeInterval, unit: Foundation.TimeInterval) -> Date {
        let completedUnits = floor(elapsedTime / unit)
        return value.addingTimeInterval((completedUnits + 1) * unit)
    }
}
