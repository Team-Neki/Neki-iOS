//
//  MetaAttributionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import Dependencies
import AppTrackingTransparency
import FacebookCore

final class MetaAttributionRepository: AttributionRepository {
    func initializeAttribution() async {
        await MainActor.run { ApplicationDelegate.shared.initializeSDK() }
    }

    @MainActor
    func checkTrackingAuthorizationStatus() -> TrackingAuthorizationStatus {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .unknown
        }
    }

    @MainActor
    func requestTrackingAuthorization() async { _ = await ATTrackingManager.requestTrackingAuthorization() }

    func trackCompleteRegistration() async {
        await MainActor.run { AppEvents.shared.logEvent(.completedRegistration) }
    }
}

extension AttributionClient: DependencyKey {
    public static var liveValue: AttributionClient {
        let repository = MetaAttributionRepository()
        
        return AttributionClient(
            initializeAttribution: { await repository.initializeAttribution() },
            checkTrackingAuthorizationStatus: { repository.checkTrackingAuthorizationStatus() },
            requestTrackingAuthorization: { await repository.requestTrackingAuthorization() },
            trackCompleteRegistration: { await repository.trackCompleteRegistration() }
        )
    }
}

extension DependencyValues {
    var attributionClient: AttributionClient {
        get { self[AttributionClient.self] }
        set { self[AttributionClient.self] = newValue }
    }
}
