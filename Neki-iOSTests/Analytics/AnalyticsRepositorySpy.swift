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

actor AnalyticsCallLog {
    private(set) var calls: [AnalyticsRepositoryCall] = []

    func append(_ call: AnalyticsRepositoryCall) {
        calls.append(call)
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

    func setUserSession(with userID: Int?) async {}

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
}
