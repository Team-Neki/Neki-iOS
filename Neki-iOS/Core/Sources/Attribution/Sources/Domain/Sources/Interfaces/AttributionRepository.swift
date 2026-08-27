//
//  AttributionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

public protocol AttributionRepository: Sendable {
    func initializeAttribution() async
    @MainActor func checkTrackingAuthorizationStatus() -> TrackingAuthorizationStatus
    @MainActor func requestTrackingAuthorization() async -> TrackingAuthorizationStatus
    @MainActor func updateTrackingAuthorization(_ status: TrackingAuthorizationStatus)
    func trackCompleteRegistration() async
}
