//
//  FirebaseAnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation
import Dependencies
import FirebaseAnalytics

public final actor FirebaseAnalyticsRepository: AnalyticsRepository {
    public init() {}

    public func initialize() async throws {}

    public func setUserSession(with userID: Int?) async {
        await MainActor.run { Analytics.setUserID(userID.map(String.init)) }
    }

    public func endUserSession(with event: any AnalyticsEvent) async {
        await MainActor.run {
            Analytics.logEvent(event.name.value, parameters: event.rawParameters)
            Analytics.setUserID(nil)
        }
    }

    public func logEvent(_ event: any AnalyticsEvent) async {
        await MainActor.run {
            Analytics.logEvent(event.name.value, parameters: event.rawParameters)
        }
    }
}
