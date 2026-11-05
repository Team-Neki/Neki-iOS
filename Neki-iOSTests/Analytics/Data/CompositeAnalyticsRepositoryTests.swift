//
//  CompositeAnalyticsRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct CompositeAnalyticsRepositoryTests {
    @Test("이벤트를 기록하면 같은 발생 정보를 등록 순서대로 모든 저장소에 넘긴다")
    func logEvent_forwardsSameOccurrenceInRegistrationOrder() async {
        let log = AnalyticsCallLog()
        let repository = makeRepository(log: log)
        let occurrence = makeOccurrence(uuid: "3FA85F64-5717-4562-B3FC-2C963F66AFA6")

        await repository.logEvent(AnalyticsEventStub.appOpen, occurrence: occurrence)
        let calls = await log.calls

        #expect(calls == [
            AnalyticsRepositoryCall(repository: "first", method: .logEvent, eventName: .appOpen, occurrence: occurrence),
            AnalyticsRepositoryCall(repository: "second", method: .logEvent, eventName: .appOpen, occurrence: occurrence)
        ])
    }

    @Test("세션을 끝내며 남기는 이벤트도 같은 발생 정보를 등록 순서대로 모든 저장소에 넘긴다")
    func endUserSession_forwardsSameOccurrenceInRegistrationOrder() async {
        let log = AnalyticsCallLog()
        let repository = makeRepository(log: log)
        let occurrence = makeOccurrence(uuid: "3FA85F64-5717-4562-B3FC-2C963F66AFA6")

        await repository.endUserSession(with: AnalyticsEventStub.withdraw, occurrence: occurrence)
        let calls = await log.calls

        #expect(calls == [
            AnalyticsRepositoryCall(repository: "first", method: .endUserSession, eventName: .withdraw, occurrence: occurrence),
            AnalyticsRepositoryCall(repository: "second", method: .endUserSession, eventName: .withdraw, occurrence: occurrence)
        ])
    }

    @Test("회원 변경과 flush도 같은 값으로 등록 순서대로 모든 저장소에 넘긴다")
    func setUserSessionAndFlush_forwardToAllRepositories() async {
        let log = AnalyticsCallLog()
        let repository = makeRepository(log: log)
        let changedAt = Date(timeIntervalSince1970: 1_793_610_697.25)

        await repository.setUserSession(with: 1, changedAt: changedAt)
        await repository.flush()
        let userSessionChanges = await log.userSessionChanges
        let flushedRepositories = await log.flushedRepositories

        #expect(userSessionChanges == [
            AnalyticsUserSessionChange(repository: "first", userID: 1, changedAt: changedAt),
            AnalyticsUserSessionChange(repository: "second", userID: 1, changedAt: changedAt)
        ])
        #expect(flushedRepositories == ["first", "second"])
    }

    @Test("동시에 기록해도 이벤트마다 자기 발생 정보를 모든 저장소에 이어서 넘긴다")
    func logEvent_whenConcurrent_keepsEachOccurrenceTogether() async {
        let log = AnalyticsCallLog()
        let repository = makeRepository(log: log)
        let appOpen = makeOccurrence(uuid: "00000000-0000-0000-0000-00000000000A")
        let mapView = makeOccurrence(uuid: "00000000-0000-0000-0000-00000000000B")

        async let first: Void = repository.logEvent(AnalyticsEventStub.appOpen, occurrence: appOpen)
        async let second: Void = repository.logEvent(AnalyticsEventStub.mapView, occurrence: mapView)
        _ = await (first, second)
        let calls = await log.calls
        let expectedOccurrences: [AnalyticsEventName: AnalyticsEventOccurrence] = [.appOpen: appOpen, .mapView: mapView]

        #expect(calls.count == 4)
        #expect(calls.map(\.repository) == ["first", "second", "first", "second"])
        #expect(calls.allSatisfy { $0.occurrence == expectedOccurrences[$0.eventName] })
        #expect(calls[0].eventName == calls[1].eventName)
        #expect(calls[2].eventName == calls[3].eventName)
        #expect(calls[0].eventName != calls[2].eventName)
    }
}


// MARK: - Helpers

private extension CompositeAnalyticsRepositoryTests {
    func makeRepository(log: AnalyticsCallLog) -> CompositeAnalyticsRepository {
        CompositeAnalyticsRepository(repositories: [
            AnalyticsRepositorySpy(name: "first", log: log),
            AnalyticsRepositorySpy(name: "second", log: log)
        ])
    }

    func makeOccurrence(uuid: String) -> AnalyticsEventOccurrence {
        AnalyticsEventOccurrence(
            id: UUID(uuidString: uuid)!,
            occurredAt: Date(timeIntervalSince1970: 1_793_610_697.25)
        )
    }
}
