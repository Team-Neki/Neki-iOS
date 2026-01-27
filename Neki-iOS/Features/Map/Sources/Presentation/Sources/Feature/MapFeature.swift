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
        var isFirstLoad: Bool = true
        
        // Map State
        var cameraPosition: GeographicCoordinate?
        var currentBounds: GeographicBoundingBox?
        
        // User Location
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
        
        // Internal Logic Actions
        case updateLocationAuthorization(CLAuthorizationStatus)
        case updateSDKAuthStatus(Bool)
        case updateUserLocation(Result<CLLocation, Error>)
        case setUserTrackingMode(Bool)
        case didDetectMapInteraction
        
        // Map Logic Actions
        case cameraMotionStarted
        case cameraMotionEnded(GeographicBoundingBox)
        case updateSearchButtonVisibility(isVisible: Bool)
        
        // Data Handling Actions
        case fetchPhotoBooths(bounds: GeographicBoundingBox)
        case photoBoothChunkLoaded([PhotoBooth])
        case photoBoothStreamFinished
        case photoBoothStreamFailure(Error)
        
        /// 비동기 계산: 브랜드 필터링 (Pruning 로직 삭제됨)
        case startBackgroundCalculation
        case didFinishBackgroundCalculation(visible: IdentifiedArrayOf<PhotoBooth>)
        
        // Binding & Child
        case binding(BindingAction<State>)
        case photoBoothListAction(PhotoBoothListFeature.Action)
    }
    
    private enum CancelID {
        case photoBoothFetch
        case locationStream
        case locationAuthorizationStream
        case sdkAuthorizationStream
        case calculation
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
                    if let location = state.userLocation { updateCameraPosition(&state, to: location.coordinate) }
                    return .none
                @unknown default:
                    return .none
                }
                
            case let .updateUserLocation(.success(location)):
                state.userLocation = location
                
                guard state.isUserTrackingMode else { return .none }
                updateCameraPosition(&state, to: location.coordinate)
                state.isSearchHereButtonVisible = false
                return .none
                
            case .updateUserLocation(.failure):
                state.isUserTrackingMode = false
                return .none
                
            case let .setUserTrackingMode(isUserTrackingMode):
                state.isUserTrackingMode = isUserTrackingMode
                return .none
                
                // MARK: - Map Camera & Search Logic
            case .didDetectMapInteraction:
                state.isUserTrackingMode = false
                return .none
                
            case .cameraMotionStarted:
                return .cancel(id: CancelID.photoBoothFetch)
                
            case let .cameraMotionEnded(bounds):
                state.currentBounds = bounds
                
                if state.isFirstLoad {
                    state.isFirstLoad = false
                    return .send(.fetchPhotoBooths(bounds: bounds))
                }
                
                guard state.isUserTrackingMode == false else { return .none }
                return .send(.updateSearchButtonVisibility(isVisible: true))
                
            case let .updateSearchButtonVisibility(isVisible):
                state.isSearchHereButtonVisible = isVisible
                return .none
                
            case .didTapSearchHereButton:
                guard let bounds = state.currentBounds else { return .none }
                return .send(.fetchPhotoBooths(bounds: bounds))
                
                // MARK: - Data Fetching
            case let .fetchPhotoBooths(bounds):
                state.isSearchHereButtonVisible = false
                state.photoBooths.removeAll()
                state.photoBoothListState.photoBooths.removeAll()
                
                return .run { send in
                    let stream = try await photoBoothClient.fetchPhotoBooths(bounds: bounds)
                    for await chunk in stream {
                        await send(.photoBoothChunkLoaded(chunk))
                    }
                    await send(.photoBoothStreamFinished)
                } catch: { error, send in
                    await send(.photoBoothStreamFailure(error))
                }.cancellable(id: CancelID.photoBoothFetch, cancelInFlight: true)
                
            case let .photoBoothChunkLoaded(chunk):
                state.photoBooths.append(contentsOf: chunk)
                return .send(.startBackgroundCalculation)
                
            case .photoBoothStreamFinished:
                return .none
                
            case let .photoBoothStreamFailure(error):
                Logger.presentation.error("PhotoBooth stream error: \(error)")
                return .none
                
            case .startBackgroundCalculation:
                let allBooths = state.photoBooths
                let activeFilters = state.photoBoothListState.filteredBrands
                return .run { send in
                    let visibleBooths: IdentifiedArrayOf<PhotoBooth>
                    if activeFilters.isEmpty {
                        visibleBooths = allBooths
                    } else {
                        visibleBooths = allBooths.filter { activeFilters.contains($0.brand) }
                    }
                    
                    await send(.didFinishBackgroundCalculation(visible: visibleBooths))
                }.cancellable(id: CancelID.calculation, cancelInFlight: true)
                
            case let .didFinishBackgroundCalculation(visible):
                state.visiblePhotoBooths = visible
                state.photoBoothListState.photoBooths = visible
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
                return .send(.startBackgroundCalculation)
                
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
    
    func updateCameraPosition(_ state: inout State, to coordinate: CLLocationCoordinate2D) {
        state.cameraPosition = .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
