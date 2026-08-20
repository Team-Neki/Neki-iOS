//
//  AttributionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import AppTrackingTransparency

public protocol AttributionRepository: Sendable {
    func initializeAttribution() async
    @MainActor func checkTrackingAuthorizationStatus() -> ATTrackingManager.AuthorizationStatus
    @MainActor func requestTrackingAuthorization() async
    func trackCompleteRegistration() async
}
