//
//  MapClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/7/26.
//

import Foundation
import CoreLocation
import ComposableArchitecture
import NMapsMap
import os

public struct MapClientConfiguration: Equatable, Sendable {
    public var distanceFilter: CLLocationDistance
    public var desiredAccuracy: CLLocationAccuracy
    
    public init(distanceFilter: CLLocationDistance = 10, desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyNearestTenMeters) {
        self.distanceFilter = distanceFilter
        self.desiredAccuracy = desiredAccuracy
    }
}

@DependencyClient
public struct MapClient {
    var locationAuthorizationStatus: @Sendable () async -> AsyncStream<CLAuthorizationStatus> = { .finished }
    var requestLocationAuthorization: @Sendable () async -> Void
    var checkSDKAuthorizationStatus: @Sendable () async -> AsyncStream<Bool> = { .finished }
    var getCurrentLocation: @Sendable () async throws -> CLLocation
    var trackingLocation: @Sendable () async -> AsyncStream<CLLocation> = { .finished }
    var configure: @Sendable (MapClientConfiguration) async -> Void
}


// MARK: - MapClient + Nested Types

extension MapClient {
    @MainActor
    final class MapDelegate: NSObject {
        let locationManager = CLLocationManager()
        
        var authStatusContinuation: AsyncStream<CLAuthorizationStatus>.Continuation?
        var sdkAuthStatusContinuation: AsyncStream<Bool>.Continuation?
        var locationContinuation: CheckedContinuation<CLLocation, Error>?
        var trackingContinuation: AsyncStream<CLLocation>.Continuation?
        
        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10
            NMFAuthManager.shared().delegate = self
        }
        
        func updateConfiguration(_ config: MapClientConfiguration) {
            locationManager.desiredAccuracy = config.desiredAccuracy
            locationManager.distanceFilter = config.distanceFilter
        }
        
        func requestLocation(_ continuation: CheckedContinuation<CLLocation, Error>) {
            if let existing = locationContinuation {
                existing.resume(throwing: CLError(.locationUnknown))
                locationContinuation = nil
            }
            
            locationContinuation = continuation
            locationManager.requestLocation()
        }
        
        func startMonitoring(_ continuation: AsyncStream<CLLocation>.Continuation) {
            trackingContinuation?.finish()
            trackingContinuation = continuation
            locationManager.startUpdatingLocation()
        }
        
        func stopMonitoring() {
            trackingContinuation?.finish()
            trackingContinuation = nil
            locationManager.stopUpdatingLocation()
        }
    }
}


// MARK: - MapClient.MapDelegate + CLLocationManagerDelegate

extension MapClient.MapDelegate: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatusContinuation?.yield(manager.authorizationStatus)
        
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        
        Task { @MainActor in
            if let locationContinuation {
                locationContinuation.resume(returning: latestLocation)
                self.locationContinuation = nil
            }
            
            trackingContinuation?.yield(latestLocation)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}


// MARK: - MapClient.MapDelegate + NMFAuthManagerDelegate

extension MapClient.MapDelegate: NMFAuthManagerDelegate {
    nonisolated func authorized(_ state: NMFAuthState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                // TODO: 네이버 지도 설정 에러 로그하기
                sdkAuthStatusContinuation?.yield(false)
                return
            }
            
            guard case .authorized = state else { sdkAuthStatusContinuation?.yield(false); return }
            sdkAuthStatusContinuation?.yield(true)
        }
    }
}


// MARK: - MapClient + DependencyKey

extension MapClient: DependencyKey {
    @MainActor
    private static let sharedDelegate = MapDelegate()
    
    public static var liveValue: MapClient = {
        MapClient {
            AsyncStream { continuation in
                Task { @MainActor in
                    sharedDelegate.authStatusContinuation = continuation
                    continuation.yield(sharedDelegate.locationManager.authorizationStatus)
                }
                
                continuation.onTermination = { _ in
                    Task { @MainActor in
                        sharedDelegate.authStatusContinuation = nil
                    }
                }
            }
        } requestLocationAuthorization: {
            await Task { @MainActor in
                sharedDelegate.locationManager.requestWhenInUseAuthorization()
            }.value
        } checkSDKAuthorizationStatus: {
            AsyncStream { continuation in
                Task { @MainActor in
                    sharedDelegate.sdkAuthStatusContinuation = continuation
                    if case .authorized = NMFAuthManager.shared().authState {
                        continuation.yield(true)
                    } else {
                        continuation.yield(false)
                    }
                }
                
                continuation.onTermination = { _ in
                    Task { @MainActor in
                        sharedDelegate.sdkAuthStatusContinuation = nil
                    }
                }
            }
        } getCurrentLocation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    sharedDelegate.requestLocation(continuation)
                }
            }
        } trackingLocation: {
            AsyncStream { continuation in
                Task { @MainActor in
                    sharedDelegate.startMonitoring(continuation)
                }
                
                continuation.onTermination = { _ in
                    Task { @MainActor in
                        sharedDelegate.stopMonitoring()
                    }
                }
            }
        } configure: { config in
            await Task { @MainActor in
                sharedDelegate.updateConfiguration(config)
            }.value
        }
    }()
}


// MARK: - MapClient + Accessor

extension DependencyValues {
    var mapClient: MapClient {
        get { self[MapClient.self] }
        set { self[MapClient.self] = newValue }
    }
}
