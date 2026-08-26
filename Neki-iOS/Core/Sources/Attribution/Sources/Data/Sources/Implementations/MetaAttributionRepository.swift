//
//  MetaAttributionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import AppTrackingTransparency
import Dependencies
import FacebookCore

final class MetaAttributionRepository: AttributionRepository {
    func initializeAttribution() async {
        await MainActor.run {
            let isAuthorized = ATTrackingManager.trackingAuthorizationStatus == .authorized
            Settings.shared.isAutoLogAppEventsEnabled = isAuthorized
            ApplicationDelegate.shared.initializeSDK()
        }
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
    func requestTrackingAuthorization() async -> TrackingAuthorizationStatus {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .unknown
        }
    }

    @MainActor
    func updateTrackingAuthorization(_ status: TrackingAuthorizationStatus) {
        let isAuthorized = status == .authorized
        Settings.shared.isAutoLogAppEventsEnabled = isAuthorized
        guard isAuthorized else { return }
        AppEvents.shared.activateApp()
    }

    func trackCompleteRegistration() async {
        await MainActor.run { AppEvents.shared.logEvent(.completedRegistration) }
    }
}


// MARK: - Dependency

private enum AttributionRepositoryKey: DependencyKey {
    static let liveValue: any AttributionRepository = MetaAttributionRepository()
}

extension DependencyValues {
    var attributionRepository: any AttributionRepository {
        get { self[AttributionRepositoryKey.self] }
        set { self[AttributionRepositoryKey.self] = newValue }
    }
}
