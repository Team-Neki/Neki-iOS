//
//  AttributionClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import Dependencies
import DependenciesMacros

@DependencyClient
public struct AttributionClient {
    public var initializeAttribution: @Sendable () async -> Void = {}
    public var resolveTrackingAuthorization: @MainActor @Sendable () async -> TrackingAuthorizationStatus = { .unknown }
    public var trackCompleteRegistration: @Sendable () async -> Void = {}
}

extension AttributionClient: DependencyKey {
    public static var liveValue: AttributionClient = {
        @Dependency(\.attributionRepository) var repository

        return AttributionClient(
            initializeAttribution: { await repository.initializeAttribution() },
            resolveTrackingAuthorization: {
                let currentStatus = repository.checkTrackingAuthorizationStatus()
                let resolvedStatus: TrackingAuthorizationStatus
                if currentStatus == .notDetermined {
                    resolvedStatus = await repository.requestTrackingAuthorization()
                } else {
                    resolvedStatus = currentStatus
                }
                repository.updateTrackingAuthorization(resolvedStatus)
                return resolvedStatus
            },
            trackCompleteRegistration: {
                guard await repository.checkTrackingAuthorizationStatus() == .authorized else { return }
                await repository.trackCompleteRegistration()
            }
        )
    }()
}

extension DependencyValues {
    var attributionClient: AttributionClient {
        get { self[AttributionClient.self] }
        set { self[AttributionClient.self] = newValue }
    }
}
