//
//  AppDiagnosticsClient.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import ComposableArchitecture

@DependencyClient
public struct AppDiagnosticsClient {
    public var fetch: @Sendable () async -> AppDiagnostics = { .empty }
}

extension AppDiagnosticsClient: TestDependencyKey {
    public static let testValue = Self(
        fetch: { .empty }
    )
}

public extension DependencyValues {
    var appDiagnosticsClient: AppDiagnosticsClient {
        get { self[AppDiagnosticsClient.self] }
        set { self[AppDiagnosticsClient.self] = newValue }
    }
}
