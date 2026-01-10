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

@DependencyClient
public struct MapClient {
    var locationAuthorizationStatus: @Sendable () async -> AsyncStream<CLAuthorizationStatus> = { .finished }
    var requestLocationAuthorization: @Sendable () async -> Void
    var checkSDKAuthorizationStatus: @Sendable () async -> AsyncStream<Bool> = { .finished }
    var userLocation: @Sendable () async -> AsyncStream<CLLocation> = { .finished }
}


// MARK: - MapClient + Nested Types

extension MapClient {
    final class MapDelegate: NSObject, CLLocationManagerDelegate, NMFAuthManagerDelegate {
        let locationManager = CLLocationManager()
        
        var authStatusContinuation: AsyncStream<CLAuthorizationStatus>.Continuation?
        var sdkAuthStatusContinuation: AsyncStream<Bool>.Continuation?
        var locationContinuation: AsyncStream<CLLocation>.Continuation?
        
        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10
            NMFAuthManager.shared().delegate = self
        }
        
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            authStatusContinuation?.yield(manager.authorizationStatus)
            
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            default:
                manager.stopUpdatingLocation()
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let lastLocation = locations.last else { return }
            locationContinuation?.yield(lastLocation)
        }
        
        func authorized(_ state: NMFAuthState, error: Error?) {
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
    public static var liveValue: MapClient = {
        let delegate = MapClient.MapDelegate()
        return MapClient {
            AsyncStream { continuation in
                delegate.authStatusContinuation = continuation
                continuation.yield(delegate.locationManager.authorizationStatus)
            }
        } requestLocationAuthorization: {
            delegate.locationManager.requestWhenInUseAuthorization()
        } checkSDKAuthorizationStatus: {
            AsyncStream { continuation in
                delegate.sdkAuthStatusContinuation = continuation
            }
        } userLocation: {
            AsyncStream { continuation in
                delegate.locationContinuation = continuation
            }
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
