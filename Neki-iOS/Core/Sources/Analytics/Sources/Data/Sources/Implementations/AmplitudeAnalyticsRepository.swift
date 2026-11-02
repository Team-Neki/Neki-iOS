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

    public func setUserSession(with userID: Int?, changedAt: Date) async {
        updateUserID(userID.map(String.init), changedAt: changedAt.epochMilliseconds)
    }

    public func endUserSession(with event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        amplitude?.track(
            eventType: event.name.value,
            eventProperties: event.rawParameters,
            options: Self.eventOptions(for: occurrence)
        )
        updateUserID(nil, changedAt: occurrence.occurredAtMilliseconds)
    }

    public func logEvent(_ event: any AnalyticsEvent, occurrence: AnalyticsEventOccurrence) async {
        amplitude?.track(
            eventType: event.name.value,
            eventProperties: event.rawParameters,
            options: Self.eventOptions(for: occurrence)
        )
    }

    public func flush() async {
        amplitude?.flush()
    }
}


// MARK: - User Session

private extension AmplitudeAnalyticsRepository {
    /// 회원 ID를 바꿉니다. 회원 ID가 없어지거나 다른 회원으로 바뀌면 같은 시각으로 새 세션을 엽니다(#383 4.4).
    /// - Note: 서버 로그의 `ServerLogSession`도 같은 시각으로 새 세션을 열어, 두 세션 ID가 같게 유지됩니다.
    /// - Note: Amplitude SDK 제거 시 `setSessionId` 호출을 지우고 `ServerLogSession`만 새 세션을 엽니다.
    func updateUserID(_ userID: String?, changedAt timestamp: Int64) {
        guard let amplitude else { return }
        let isLeaving = amplitude.getUserId().map { $0 != userID } ?? false
        amplitude.setUserId(userId: userID)
        if isLeaving { amplitude.setSessionId(timestamp: timestamp) }
    }
}


// MARK: - Identity

extension AmplitudeAnalyticsRepository: AnalyticsIdentityProviding {
    /// Amplitude가 UserDefaults에 저장해 둔 `device_id`
    /// - Note: Amplitude SDK 제거 시 같은 suite(`com.amplitude.storage.amplitude-swift-storage-<API 키>-$default_instance`)의 `device_id`를 직접 읽습니다. 값이 없으면 SDK와 같은 규칙(IDFV → UUID)으로 만들어 같은 키에 씁니다. suite 이름에 API 키가 들어가므로 키 값은 SDK를 걷어 낸 뒤에도 남겨 둡니다.
    func deviceID() -> String? {
        amplitude?.getDeviceId()
    }

    /// 지금 Amplitude 세션 ID. 세션이 없으면 -1
    /// - Note: Amplitude SDK 제거 시 `ServerLogSession`이 계산한 값을 씁니다.
    func sessionID() -> Int64 {
        amplitude?.getSessionId() ?? -1
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
