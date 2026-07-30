//
//  AmplitudeAnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import AmplitudeSwift
import Foundation

public final actor AmplitudeAnalyticsRepository: AnalyticsRepository {
    private let amplitude: Amplitude

    public init(apiKey: String) {
        let configuration = Configuration(
            apiKey: apiKey,
            autocapture: [],
            enableAutoCaptureRemoteConfig: false
        )
        self.amplitude = Amplitude(configuration: configuration)
    }

    public func setUserSession(with userID: Int?) async {
        amplitude.setUserId(userId: userID.map(String.init))
    }

    public func logEvent(_ event: any AnalyticsEvent) async {
        amplitude.track(
            eventType: event.name.value,
            eventProperties: event.rawParameters
        )
    }
}
