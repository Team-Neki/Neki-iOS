//
//  AttributionClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import DependenciesMacros

@DependencyClient
public struct AttributionClient {
    public var initializeAttribution: @Sendable () async -> Void = {}
    public var checkTrackingAuthorizationStatus: @MainActor @Sendable () -> TrackingAuthorizationStatus = { .notDetermined }
    public var requestTrackingAuthorization: @MainActor @Sendable () async -> Void = {}
    public var trackCompleteRegistration: @Sendable () async -> Void = {}
}
