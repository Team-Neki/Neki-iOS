//
//  MapFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/7/26.
//

import UIKit
import ComposableArchitecture
import CoreLocation
import os

@Reducer
public struct MapFeature {
    private enum Constants {
        /// 재검색 버튼 노출 기준 거리: 2Km
        static let searchTriggerDistanceThreshold: Double = 2000.0
    }
    
    enum SheetStage {
        case first, second, third, photoBoothSelected
        
        var detent: NekiSheetDetent {
            switch self {
            case .first: return .fraction(0.134)
            case .second: return .fraction(0.305)
            case .third: return .large
            case .photoBoothSelected: return .hidden
            }
        }
    }
    
    @ObservableState
    public struct State {
        // UI Control
        var isSDKAuthSuccessful: Bool = false
        var detent: NekiSheetDetent = SheetStage.first.detent
        var isSearchHereButtonVisible: Bool = false
        
        // Map State
        var cameraPosition: GeographicCoordinate?
        var currentBounds: GeographicBoundingBox?
        var lastFetchedLocation: GeographicCoordinate?
        
        // User Location & Tracking
        var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
        var userLocation: CLLocation?
        var isUserTrackingMode: Bool = false
        var locationAuthorizationNeeded: Bool = true
        var isLocationAuthorized: Bool { locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse }
        
        // Data
        var photoBooths: IdentifiedArrayOf<PhotoBooth> = []
        var visiblePhotoBooths: IdentifiedArrayOf<PhotoBooth> = []
        var selectedBooth: PhotoBooth?
        var directionSheetPhotoBooth: PhotoBooth?
        
        // Child State
        var photoBoothListState = PhotoBoothListFeature.State()
    }
    
    public enum Action: BindableAction {
        // View Actions
        case onAppear
        case onDisappear
        case requestPermission
        case openAppSettings
        case didTapGoBackToMapButton
        case didTapBooth(PhotoBooth)
        case didTapCloseDetail
        case didTapCurrentLocationButton
        case didTapDirectionAppsButton
        case didTapSearchHereButton
        
        // Internal Actions
        case updateLocationAuthorization(CLAuthorizationStatus)
        case updateSDKAuthStatus(Bool)
        case updateUserLocation(Result<CLLocation, Error>)
        case setUserTrackingMode(Bool)
        case didDetectMapInteraction
        case photoBoothChunkLoaded([PhotoBooth])
        case photoBoothStreamFinished
        case photoBoothStreamFailure(Error)
        case cameraMotionStarted
        case cameraMotionEnded(GeographicBoundingBox)
        case updateSearchButtonVisibility(isVisible: Bool)
        
        // Binding Action
        case binding(BindingAction<State>)
        
        // Child Actions
        case photoBoothListAction(PhotoBoothListFeature.Action)
    }
    
    private enum CancelID {
        case photoBoothFetch
        case locationStream
        case locationAuthorizationStream
        case sdkAuthorizationStream
        case distanceCalculation
    }
    
    @Dependency(\.mapClient) private var mapClient
    @Dependency(\.photoBoothClient) private var photoBoothClient
    @Dependency(\.openURL) private var openURL
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.photoBoothListState, action: \.photoBoothListAction) { PhotoBoothListFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                
                // MARK: - Life Cycle & Streams
            case .onAppear:
                return .merge(
                    .run { send in
                        for await status in await mapClient.locationAuthorizationStatus() {
                            await send(.updateLocationAuthorization(status))
                        }
                    }.cancellable(id: CancelID.locationAuthorizationStream, cancelInFlight: true),
                    .run { send in
                        for await isAuthorized in await mapClient.checkSDKAuthorizationStatus() {
                            await send(.updateSDKAuthStatus(isAuthorized))
                        }
                    }.cancellable(id: CancelID.sdkAuthorizationStream, cancelInFlight: true)
                )
                
            case .onDisappear:
                return .cancel(id: CancelID.locationStream)
                
                // MARK: - Permission Flow
            case .requestPermission:
                state.locationAuthorizationNeeded = true
                return .run { _ in await mapClient.requestLocationAuthorization() }
                
            case .updateLocationAuthorization(let status):
                state.locationAuthorizationStatus = status
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    return .merge(
                        .run { send in
                            for await location in await mapClient.trackingLocation() {
                                await send(.updateUserLocation(.success(location)))
                            }
                        }.cancellable(id: CancelID.locationStream, cancelInFlight: true),
                        .send(.didTapCurrentLocationButton)
                    )
                    
                case .notDetermined:
                    return state.locationAuthorizationNeeded ? .send(.requestPermission) : .none
                    
                default:
                    state.isUserTrackingMode = false
                    return .none
                }
                
            case .openAppSettings:
                // TODO: 설정 앱 동작 전에 안내문구 따위를 보여주도록 해야하는데 디자인 가이드가 없습니다.
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }
                
                // MARK: - User Location Interaction
            case .didTapCurrentLocationButton:
                switch state.locationAuthorizationStatus {
                case .notDetermined:
                    return .send(.requestPermission)
                case .restricted, .denied:
                    return .send(.openAppSettings)
                case .authorizedAlways, .authorizedWhenInUse, .authorized:
                    state.isUserTrackingMode = true
                    if let location = state.userLocation { updateCameraPosition(&state, to: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)) }
                    return .none
                @unknown default:
                    return .none
                }
                
            case let .updateUserLocation(.success(location)):
                state.userLocation = location
                if state.isUserTrackingMode {
                    updateCameraPosition(&state, to: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
                    state.isSearchHereButtonVisible = false
                }
                
                guard state.lastFetchedLocation == nil else { return .none }
                return .send(.didTapSearchHereButton)
                
            case .updateUserLocation(.failure):
                state.isUserTrackingMode = false
                return .none
                
            case let .setUserTrackingMode(isUserTrackingMode):
                state.isUserTrackingMode = isUserTrackingMode
                return .none
                
                // MARK: - Map Camera & Search Logic
            case .cameraMotionStarted:
                return .cancel(id: CancelID.photoBoothFetch)
                
            case let .cameraMotionEnded(bounds):
                state.currentBounds = bounds
                guard let lastFetchedLocation = state.lastFetchedLocation else { return .none }
                return .run { send in
                    let distance = calculateDistance(bounds: bounds, lastFetched: lastFetchedLocation)
                    let isVisible = distance >= Constants.searchTriggerDistanceThreshold
                    await send(.updateSearchButtonVisibility(isVisible: isVisible))
                }.cancellable(id: CancelID.distanceCalculation, cancelInFlight: true)
                
            case let .updateSearchButtonVisibility(isVisible):
                state.isSearchHereButtonVisible = isVisible
                return .none
                
            case .didDetectMapInteraction:
                state.isUserTrackingMode = false
                return .none
                
            case .didTapSearchHereButton:
                guard let bounds = state.currentBounds else { return .none }
                state.isSearchHereButtonVisible = false
                state.lastFetchedLocation = bounds.center
                return .run { send in
                    let stream = try await photoBoothClient.fetchPhotoBooths(bounds)
                    
                    for await chunk in stream { await send(.photoBoothChunkLoaded(chunk)) }
                    await send(.photoBoothStreamFinished)
                } catch: { error, send in
                    await send(.photoBoothStreamFailure(error))
                }
                .cancellable(id: CancelID.photoBoothFetch, cancelInFlight: true)
                
            case let .photoBoothChunkLoaded(chunk):
                state.photoBooths.append(contentsOf: chunk)
                handleFilterOptionChanged(&state)
                return .none
                
            case .photoBoothStreamFinished:
                return .none
                
            case let .photoBoothStreamFailure(error):
                Logger.presentation.error("PhotoBooth stream error: \(error)")
                return .none
                
            case .didTapGoBackToMapButton:
                resetToMapMode(&state, for: .first)
                return .none
                
            case .didTapBooth(let photoBooth):
                state.isUserTrackingMode = false
                selectPhotoBooth(&state, photoBooth: photoBooth)
                return .none
                
            case .didTapCloseDetail:
                resetToMapMode(&state, for: .second)
                return .none
                
                
            case .didTapDirectionAppsButton:
                state.directionSheetPhotoBooth = state.selectedBooth
                return .none
                
            case .updateSDKAuthStatus(let isAuthorized):
                state.isSDKAuthSuccessful = isAuthorized
                return .none
                
            case .photoBoothListAction(.selectFilterOption):
                handleFilterOptionChanged(&state)
                return .none
                
            case let .photoBoothListAction(.didTapBooth(photoBooth)):
                return .send(.didTapBooth(photoBooth))
                
            default:
                return .none
            }
        }
    }
}


// MARK: - MapFeature + Effect Handlers

private extension MapFeature {
    func resetToMapMode(_ state: inout State, for stage: SheetStage) {
        state.selectedBooth = nil
        state.detent = stage.detent
        state.cameraPosition = nil
    }
    
    func selectPhotoBooth(_ state: inout State, photoBooth: PhotoBooth) {
        state.selectedBooth = photoBooth
        state.detent = SheetStage.photoBoothSelected.detent
        state.cameraPosition = photoBooth.coordinate
    }
    
    func handleFilterOptionChanged(_ state: inout State) {
        let activeFilters = state.photoBoothListState.filteredBrands
        if activeFilters.isEmpty {
            state.visiblePhotoBooths = state.photoBooths
        } else {
            state.visiblePhotoBooths = state.photoBooths.filter { activeFilters.contains($0.brand) }
        }
        
        state.photoBoothListState.photoBooths = state.visiblePhotoBooths
    }
    
    func updateCameraPosition(_ state: inout State, to location: GeographicCoordinate) {
        state.cameraPosition = .init(latitude: location.latitude, longitude: location.longitude)
    }
    
    func calculateDistance(bounds: GeographicBoundingBox, lastFetched: GeographicCoordinate) -> Double {
        let currentCenter = bounds.center
        let from = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
        let to = CLLocation(latitude: lastFetched.latitude, longitude: lastFetched.longitude)
        return from.distance(from: to)
    }
}
