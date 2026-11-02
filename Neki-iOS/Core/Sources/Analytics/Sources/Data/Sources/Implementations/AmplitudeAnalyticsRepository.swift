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
                minIdLength: configuration.minimumIdentifierLength,
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

    public func endUserSession(with event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        amplitude?.track(
            eventType: event.name.value,
            eventProperties: event.rawParameters,
            options: Self.eventOptions(for: occurrence)
        )
        amplitude?.setUserId(userId: nil)
    }

    public func logEvent(_ event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        amplitude?.track(
            eventType: event.name.value,
            eventProperties: event.rawParameters,
            options: Self.eventOptions(for: occurrence)
        )
    }
}


// MARK: - Event Options

extension AmplitudeAnalyticsRepository {
    /// 발생 정보를 Amplitude 이벤트의 `insert_id`와 `time`으로 넘깁니다.
    /// - Note: SDK는 두 값이 비어 있을 때만 직접 채우므로, 넘긴 값이 그대로 남습니다.
    /// - Note: Amplitude SDK 제거 시 이 코드는 저장소와 함께 지웁니다. 그 뒤의 Amplitude 대조는 서버 로그를 Amplitude로 옮기는 서버 작업이 `eventId`를 `insert_id`로 써서 이어 갑니다.
    static func eventOptions(for occurrence: AnalyticsEventOccurrence) -> EventOptions {
        EventOptions(timestamp: occurrence.occurredAtMilliseconds, insertId: occurrence.id)
    }
}
