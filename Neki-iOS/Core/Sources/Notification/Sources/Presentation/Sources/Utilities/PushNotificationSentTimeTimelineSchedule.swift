//
//  PushNotificationSentTimeTimelineSchedule.swift
//  Neki-iOS
//
//  Created by Codex on 7/23/26.
//

import SwiftUI

struct PushNotificationSentTimeTimelineSchedule: TimelineSchedule {
    let sentTimes: [PushNotificationSentTime]

    func entries(from startDate: Date, mode _: TimelineScheduleMode) -> Entries {
        Entries(sentTimes: sentTimes, currentDate: startDate)
    }
}

extension PushNotificationSentTimeTimelineSchedule {
    struct Entries: Sequence, IteratorProtocol {
        let sentTimes: [PushNotificationSentTime]
        var currentDate: Date
        private var isInitialEntry = true

        init(sentTimes: [PushNotificationSentTime], currentDate: Date) {
            self.sentTimes = sentTimes
            self.currentDate = currentDate
        }

        mutating func next() -> Date? {
            guard isInitialEntry == false else {
                isInitialEntry = false
                return currentDate
            }

            guard let nextUpdateDate = sentTimes.lazy
                .map({ $0.nextRelativeValueUpdateDate(after: currentDate) })
                .min()
            else { return nil }

            currentDate = nextUpdateDate
            return nextUpdateDate
        }
    }
}
