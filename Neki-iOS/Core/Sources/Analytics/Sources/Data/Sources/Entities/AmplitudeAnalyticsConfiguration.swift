//
//  AmplitudeAnalyticsConfiguration.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/1/26.
//

import Foundation

struct AmplitudeAnalyticsConfiguration: Sendable {
    private enum Constants {
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
