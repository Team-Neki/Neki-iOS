//
//  AnalyticsClientTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Dependencies
import Foundation
import Testing
@testable import Neki_iOS

struct AnalyticsClientTests {
    @Test("기록 요청마다 그 시점의 UUID와 시각으로 발생 정보를 하나씩 만들어 넘긴다")
    func liveValue_createsOccurrenceForEachCall() async {
        let log = AnalyticsCallLog()
        let occurredAt = Date(timeIntervalSince1970: 1_793_610_697.25)

        await withDependencies {
            $0.analyticsRepository = AnalyticsRepositorySpy(name: "composite", log: log)
            $0.uuid = .incrementing
            $0.date = .constant(occurredAt)
        } operation: {
            await AnalyticsClient.liveValue.logEvent(AnalyticsEventStub.appOpen)
            await AnalyticsClient.liveValue.endUserSession(AnalyticsEventStub.logout)
        }
        let calls = await log.calls

        #expect(calls == [
            AnalyticsRepositoryCall(
                repository: "composite",
                method: .logEvent,
                eventName: .appOpen,
                occurrence: AnalyticsEventOccurrence(id: UUID(0), occurredAt: occurredAt)
            ),
            AnalyticsRepositoryCall(
                repository: "composite",
                method: .endUserSession,
                eventName: .logout,
                occurrence: AnalyticsEventOccurrence(id: UUID(1), occurredAt: occurredAt)
            )
        ])
    }

    @Test("회원 변경은 그 시점의 시각과 함께 넘기고, flush는 그대로 넘긴다")
    func liveValue_forwardsUserChangeTimeAndFlush() async {
        let log = AnalyticsCallLog()
        let changedAt = Date(timeIntervalSince1970: 1_793_610_697.25)

        await withDependencies {
            $0.analyticsRepository = AnalyticsRepositorySpy(name: "composite", log: log)
            $0.date = .constant(changedAt)
        } operation: {
            await AnalyticsClient.liveValue.setUserSession(1)
            await AnalyticsClient.liveValue.flush()
        }
        let userSessionChanges = await log.userSessionChanges
        let flushedRepositories = await log.flushedRepositories

        #expect(userSessionChanges == [AnalyticsUserSessionChange(repository: "composite", userID: 1, changedAt: changedAt)])
        #expect(flushedRepositories == ["composite"])
    }

    @Test("이벤트 ID는 소문자 UUID 문자열로 만든다")
    func occurrence_usesLowercasedUUIDString() {
        let occurrence = AnalyticsEventOccurrence(
            id: UUID(uuidString: "3FA85F64-5717-4562-B3FC-2C963F66AFA6")!,
            occurredAt: Date(timeIntervalSince1970: 0)
        )

        #expect(occurrence.id == "3fa85f64-5717-4562-b3fc-2c963f66afa6")
    }

    @Test("발생 시각은 밀리초 아래를 버린 epoch milliseconds로 만든다")
    func occurrence_truncatesBelowMilliseconds() {
        // 1_793_610_697.2509765625초는 이진수로 정확히 표현되며, 1_793_610_697_250.9765625ms다.
        let occurrence = AnalyticsEventOccurrence(
            id: UUID(0),
            occurredAt: Date(timeIntervalSince1970: 1_793_610_697.2509765625)
        )

        #expect(occurrence.occurredAtMilliseconds == 1_793_610_697_250)
    }
}
