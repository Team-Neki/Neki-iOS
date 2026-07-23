//
//  PushNotificationSentTimeTimelineSchedule.swift
//  Neki-iOS
//
//  Created by Codex on 7/23/26.
//

import SwiftUI

struct PushNotificationSentTimeTimelineSchedule: TimelineSchedule {
    typealias Entries = UnfoldFirstSequence<Date>

    let sentTime: PushNotificationSentTime

    func entries(from startDate: Date, mode _: TimelineScheduleMode) -> Entries {
        sequence(first: startDate) { [sentTime] currentDate in
            sentTime.nextRelativeValueUpdateDate(after: currentDate)
        }
    }
}
