//
//  AmplitudeAnalyticsConfiguration.swift
//  Neki-iOS
//
//  Created by Codex on 8/1/26.
//

import Foundation

struct AmplitudeAnalyticsConfiguration: Sendable {
    private enum InfoKey {
        static let apiKey = "AMPLITUDE_API_KEY"
    }

    let apiKey: String

    init(bundle: Bundle = .main) throws {
        guard let apiKey = bundle.object(forInfoDictionaryKey: InfoKey.apiKey) as? String,
              apiKey.isEmpty == false,
              apiKey.hasPrefix("$(") == false
        else { throw AmplitudeAnalyticsConfigurationError.missingAPIKey }

        self.apiKey = apiKey
    }
}

enum AmplitudeAnalyticsConfigurationError: Error {
    case missingAPIKey
}
