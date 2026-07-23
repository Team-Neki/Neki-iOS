//
//  PushNotificationSentTimeTimelineSchedule.swift
//  Neki-iOS
//
//  Created by Codex on 7/23/26.
//

import SwiftUI

struct PushNotificationSentTimeTimelineSchedule: TimelineSchedule {
    typealias Entries = UnfoldFirstSequence<Date>

    let sentTimes: [PushNotificationSentTime]

    func entries(from startDate: Date, mode _: TimelineScheduleMode) -> Entries {
        let sentTimes = sentTimes
        return sequence(first: startDate) { currentDate in
            sentTimes.lazy
                .map { $0.nextRelativeValueUpdateDate(after: currentDate) }
                .min()
        }
    }
}
