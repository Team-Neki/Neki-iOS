//
//  AmplitudeAnalyticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import AmplitudeSwift
import Foundation

public final actor AmplitudeAnalyticsRepository: AnalyticsRepository {
    private let amplitude: Amplitude?
    private let initializationError: AmplitudeAnalyticsConfigurationError?

    public init() {
        do {
            let configuration = try AmplitudeAnalyticsConfiguration()
            let amplitudeConfiguration = Configuration(
                apiKey: configuration.apiKey,
                autocapture: .appLifecycles,
                enableAutoCaptureRemoteConfig: false
            )
            self.amplitude = Amplitude(configuration: amplitudeConfiguration)
            self.initializationError = nil
        } catch let error as AmplitudeAnalyticsConfigurationError {
            self.amplitude = nil
            self.initializationError = error
        } catch {
            self.amplitude = nil
            self.initializationError = .missingAPIKey
        }
    }

    public func initialize() async throws {
        guard let initializationError else { return }
        throw initializationError
    }

    public func setUserSession(with userID: Int?) async {
        amplitude?.setUserId(userId: userID.map(String.init))
    }

    public func logEvent(_ event: any AnalyticsEvent) async {
        amplitude?.track(
            eventType: event.name.value,
            eventProperties: event.rawParameters
        )
    }
}
