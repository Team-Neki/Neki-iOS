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
    public var setUserSession: @Sendable (_ userID: Int?) async -> Void = { _ in }
    public var endUserSession: @Sendable (_ event: any AnalyticsEvent) async -> Void = { _ in }
    public var logEvent: @Sendable (_ event: any AnalyticsEvent) async -> Void = { _ in }
}

extension AnalyticsClient: DependencyKey {
    public static var liveValue: AnalyticsClient = {
        @Dependency(\.analyticsRepository) var repository
        
        return AnalyticsClient {
            try await repository.initialize()
        } setUserSession: { userID in
            await repository.setUserSession(with: userID)
        } endUserSession: { event in
            await repository.logEvent(event)
            await repository.setUserSession(with: nil)
        } logEvent: { event in
            await repository.logEvent(event)
        }
    }()
}

extension DependencyValues {
    var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
