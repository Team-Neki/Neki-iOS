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
    public var configure: (_ userID: Int?) -> Void
    public var logEvent: (_ event: AnalyticsEvent) -> Void
}

extension AnalyticsClient: DependencyKey {
    public static var liveValue: AnalyticsClient = {
        @Dependency(\.analyticsRepository) var repository
        
        return AnalyticsClient { userID in
            Task.detached(priority: .background) { await repository.setUserSession(with: userID) }
        } logEvent: { event in
            Logger.domain.info("📊 [GA4 Event] 명칭: \(event.name.value, privacy: .public) | 파라미터: \(String(describing: event.parameters ?? [:]), privacy: .public)")
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
