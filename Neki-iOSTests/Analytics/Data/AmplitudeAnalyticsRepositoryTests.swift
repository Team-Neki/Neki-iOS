//
//  AmplitudeAnalyticsRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import AmplitudeSwift
import Foundation
import Testing
@testable import Neki_iOS

struct AmplitudeAnalyticsRepositoryTests {
    @Test("발생 정보의 ID와 시각을 Amplitude 이벤트의 insert_id와 time으로 넘긴다")
    func eventOptions_passOccurrenceAsInsertIDAndTime() {
        let occurrence = AnalyticsEventOccurrence(
            id: UUID(uuidString: "3FA85F64-5717-4562-B3FC-2C963F66AFA6")!,
            occurredAt: Date(timeIntervalSince1970: 1_793_610_697.25)
        )

        let options = AmplitudeAnalyticsRepository.eventOptions(for: occurrence)

        #expect(options.insertId == "3fa85f64-5717-4562-b3fc-2c963f66afa6")
        #expect(options.timestamp == 1_793_610_697_250)
        #expect(options.eventId == nil)
    }
}
