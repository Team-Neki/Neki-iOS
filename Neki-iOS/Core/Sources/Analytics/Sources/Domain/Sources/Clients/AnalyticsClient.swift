//
//  AnalyticsClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation
import Dependencies
import DependenciesMacros
import os

@DependencyClient
public struct AnalyticsClient {
    public var initialize: @Sendable () async throws -> Void
    public var configure: (_ userID: Int?) -> Void
    public var logEvent: (_ event: AnalyticsEvent) -> Void
}

extension AnalyticsClient: DependencyKey {
    public static var liveValue: AnalyticsClient = {
        @Dependency(\.analyticsRepository) var repository
        
        return AnalyticsClient {
            try await repository.initialize()
        } configure: { userID in
            Task.detached(priority: .background) { await repository.setUserSession(with: userID) }
        } logEvent: { event in
            Task.detached(priority: .background) { await repository.logEvent(event) }
        }
    }()
}

extension DependencyValues {
    var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
