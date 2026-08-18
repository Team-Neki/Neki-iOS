//
//  AmplitudeAnalyticsConfiguration.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/1/26.
//

import Foundation

struct AmplitudeAnalyticsConfiguration: Sendable {
    private enum Constants {
        /// Amplitude 이벤트 추적에 필요한 ID의 최소길이
        /// - Note: 최신 Amplitude의 API는 다섯 자 이상이어야 정상 수신되지만, Neki의 사용자ID는 양의 정수이므로 최대 식별자 길이를 1로 설정하는 것이 필수입니다.
        static let minimumIdentifierLength = 1
    }

    private enum InfoKey {
        static let apiKey = "AMPLITUDE_API_KEY"
    }

    let apiKey: String
    let minimumIdentifierLength: Int

    init(bundle: Bundle = .main) throws {
        guard let apiKey = bundle.object(forInfoDictionaryKey: InfoKey.apiKey) as? String,
              apiKey.isEmpty == false,
              apiKey.hasPrefix("$(") == false
        else { throw AmplitudeAnalyticsConfigurationError.missingAPIKey }

        self.apiKey = apiKey
        self.minimumIdentifierLength = Constants.minimumIdentifierLength
    }
}

enum AmplitudeAnalyticsConfigurationError: Error {
    case missingAPIKey
}
