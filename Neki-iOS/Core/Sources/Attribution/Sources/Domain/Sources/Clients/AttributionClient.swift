//
//  AttributionClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import AppTrackingTransparency
import DependenciesMacros

@DependencyClient
public struct AttributionClient {
    public typealias AuthorizationStatus = ATTrackingManager.AuthorizationStatus

    public var initializeAttribution: @Sendable () async -> Void = {}
    public var checkTrackingAuthorizationStatus: @MainActor @Sendable () -> AuthorizationStatus = { .notDetermined }
    public var requestTrackingAuthorization: @MainActor @Sendable () async -> Void = {}
    public var trackCompleteRegistration: @Sendable () async -> Void = {}
}
