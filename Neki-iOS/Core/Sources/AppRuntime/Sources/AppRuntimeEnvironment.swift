//
//  AppRuntimeEnvironment.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import Foundation

public enum AppRuntimeDistributionChannel: String, Sendable {
    case debug
    case testFlight
    case appStore
}

public enum AppRuntimeEnvironment {
    public static var distributionChannel: AppRuntimeDistributionChannel {
        #if DEBUG
        return .debug
        #else
        guard Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" else { return .appStore }
        return .testFlight
        #endif
    }

    public static var isDeveloperDiagnosticsAvailable: Bool {
        #if DEBUG
        return true
        #else
        return distributionChannel == .testFlight || Bundle.main.bundleIdentifier?.contains("Neki-dev") == true
        #endif
    }

    public static var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
}
