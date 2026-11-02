//
//  AnalyticsRepositorySpy.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
@testable import Neki_iOS

enum AnalyticsEventStub: AnalyticsEvent {
    case appOpen
    case mapView
    case logout
    case withdraw

    var name: AnalyticsEventName {
        switch self {
        case .appOpen: .appOpen
        case .mapView: .mapView
        case .logout: .logout
        case .withdraw: .withdraw
        }
    }

    var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? { nil }
}

struct AnalyticsRepositoryCall: Equatable {
    enum Method: Equatable {
        case logEvent
        case endUserSession
    }

    let repository: String
    let method: Method
    let eventName: AnalyticsEventName
    let occurrence: AnalyticsEventOccurrence
}

struct AnalyticsUserSessionChange: Equatable {
    let repository: String
    let userID: Int?
    let changedAt: Date
}

actor AnalyticsCallLog {
    private(set) var calls: [AnalyticsRepositoryCall] = []
    private(set) var userSessionChanges: [AnalyticsUserSessionChange] = []
    private(set) var flushedRepositories: [String] = []

    func append(_ call: AnalyticsRepositoryCall) {
        calls.append(call)
    }

    func append(_ change: AnalyticsUserSessionChange) {
        userSessionChanges.append(change)
    }

    func appendFlush(repository: String) {
        flushedRepositories.append(repository)
    }
}

actor AnalyticsRepositorySpy: AnalyticsRepository {
    private let name: String
    private let log: AnalyticsCallLog

    init(name: String, log: AnalyticsCallLog) {
        self.name = name
        self.log = log
    }

    func initialize() async throws {}

    func setUserSession(with userID: Int?, changedAt: Date) async {
        await log.append(AnalyticsUserSessionChange(repository: name, userID: userID, changedAt: changedAt))
    }

    func endUserSession(with event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        await log.append(AnalyticsRepositoryCall(
            repository: name,
            method: .endUserSession,
            eventName: event.name,
            occurrence: occurrence
        ))
    }

    func logEvent(_ event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        await log.append(AnalyticsRepositoryCall(
            repository: name,
            method: .logEvent,
            eventName: event.name,
            occurrence: occurrence
        ))
    }

    func flush() async {
        await log.appendFlush(repository: name)
    }
}
