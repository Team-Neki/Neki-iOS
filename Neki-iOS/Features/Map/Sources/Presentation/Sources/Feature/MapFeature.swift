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
    enum Constants {
        static let defaultInitialPosition: CLLocation = .init(latitude: 37.498095, longitude: 127.027610)
        static let cameraTargetDistanceThreshold: CLLocationDistance = 200
        static let regionChangeDistanceThreshold: CLLocationDistance = 500
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
        var isFirstLoad: Bool = true
        var isPermissionAlertPresented: Bool = false
        
        // Map State
        var cameraPosition: GeographicCoordinate?
        var currentBounds: GeographicBoundingBox?
        var lastSearchedLocation: CLLocation?
        
        // User Location
        var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
        var userLocation: CLLocation?
        var userGeographicCoordinate: GeographicCoordinate? {
            guard let location = userLocation else { return nil }
            return .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
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
        case didTapBoothCard
        case didTapCloseDetail
        case didTapCurrentLocationButton
        case didTapDirectionAppsButton
        case didTapSearchHereButton
        case dismissPermissionAlert
        
        // Internal Logic Actions
        case updateLocationAuthorization(CLAuthorizationStatus)
        case updateSDKAuthStatus(Bool)
        case updateUserLocation(Result<CLLocation, Error>)
        case setUserTrackingMode(Bool)
        case didDetectMapInteraction
        case presentPermissionAlert
        
        // Map Logic Actions
        case mapLoaded(GeographicBoundingBox)
        case cameraMotionStarted
        case cameraMotionEnded(GeographicBoundingBox)
        case updateSearchButtonVisibility(isVisible: Bool)
        
        // Data Handling Actions
        // Map
        case fetchPhotoBooths(bounds: GeographicBoundingBox)
        case photoBoothChunkLoaded([PhotoBooth])
        case photoBoothStreamFinished
        case photoBoothStreamFailure(Error)
        case loadBrands
        case brandsResponse(Result<[PhotoBoothBrand], Error>)
        
        // Sheet
        case fetchNearbyPhotoBooths(GeographicCoordinate)
        case nearbyPhotoBoothResponse(Result<[PhotoBooth], Error>)
        case startBackgroundCalculation
        case processNewChunk([PhotoBooth], isFirstBatch: Bool)
        case appendProcessedChunk(map: [PhotoBooth], isFirstBatch: Bool)
        case didFinishBackgroundCalculation(map: IdentifiedArrayOf<PhotoBooth>, list: IdentifiedArrayOf<PhotoBooth>)
        
        // Binding & Child
        case binding(BindingAction<State>)
        case photoBoothListAction(PhotoBoothListFeature.Action)
    }
    
    private enum CancelID {
        case mapFetch
        case listFetch
        case locationStream
        case locationAuthorizationStream
        case sdkAuthorizationStream
        case calculation
    }
    
    @Dependency(\.mapClient) private var mapClient
    @Dependency(\.photoBoothClient) private var photoBoothClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.openURL) private var openURL
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.photoBoothListState, action: \.photoBoothListAction) { PhotoBoothListFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                
                // MARK: - Life Cycle & Streams
            case .onAppear:
                return .merge(
                    .run { _ in analytics.logEvent(MapAnalyticsEvent.mapView) },
                    .send(.loadBrands),
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
                    
                case .denied, .restricted:
                    state.isUserTrackingMode = false
                    
                    guard state.isFirstLoad, let bounds = state.currentBounds else { return .none }
                    state.isFirstLoad = false
                    return .merge(
                        .send(.fetchPhotoBooths(bounds: bounds)),
                        .send(.fetchNearbyPhotoBooths(bounds.center))
                    )
                    
                @unknown default:
                    return .none
                }
                
            case .presentPermissionAlert:
                state.isPermissionAlertPresented = true
                return .none
                
            case .dismissPermissionAlert:
                state.isPermissionAlertPresented = false
                return .none
                
            case .openAppSettings:
                state.isPermissionAlertPresented = false
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }
                
                // MARK: - User Location Interaction
            case let .mapLoaded(bounds):
                state.currentBounds = bounds
                state.cameraPosition = bounds.center
                return .none
                
            case .didTapCurrentLocationButton:
                resetToMapMode(&state, for: .first)
                switch state.locationAuthorizationStatus {
                case .notDetermined:
                    return .send(.requestPermission)
                case .restricted, .denied:
                    return .send(.presentPermissionAlert)
                case .authorizedAlways, .authorizedWhenInUse, .authorized:
                    state.isUserTrackingMode = true
                    if let location = state.userLocation { updateCameraPosition(&state, to: location.coordinate) }
                    return .none
                @unknown default:
                    return .none
                }
                
            case let .updateUserLocation(.success(location)):
                state.userLocation = location
                
                if state.isFirstLoad || state.isUserTrackingMode {
                    updateCameraPosition(&state, to: location.coordinate)
                    guard state.isFirstLoad else { return .none }
                    state.isSearchHereButtonVisible = false
                }
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
                return .merge(
                    .cancel(id: CancelID.mapFetch),
                    .cancel(id: CancelID.listFetch)
                )
                
            case .cameraMotionStarted:
                return .send(.updateSearchButtonVisibility(isVisible: true))
                
            case let .cameraMotionEnded(bounds):
                state.currentBounds = bounds
                state.cameraPosition = bounds.center
                
                guard state.isFirstLoad else { return .none }
                guard state.locationAuthorizationStatus != .notDetermined else { return .none }
                
                let targetCoordinate = state.isLocationAuthorized ? (state.userLocation ?? Constants.defaultInitialPosition) : Constants.defaultInitialPosition
                let currentCameraLocation = CLLocation(latitude: bounds.center.latitude, longitude: bounds.center.longitude)
                
                guard currentCameraLocation.distance(from: targetCoordinate) <= Constants.cameraTargetDistanceThreshold else { return .none }
                state.isFirstLoad = false
                let nearbyTargetCoordinate = state.userGeographicCoordinate ?? bounds.center
                state.lastSearchedLocation = currentCameraLocation
                return .merge(
                    .send(.fetchPhotoBooths(bounds: bounds)),
                    .send(.fetchNearbyPhotoBooths(nearbyTargetCoordinate))
                )
                
            case let .updateSearchButtonVisibility(isVisible):
                state.isSearchHereButtonVisible = isVisible
                return .none
                
            case .didTapSearchHereButton:
                guard let bounds = state.currentBounds else { return .none }
                let nearbyTargetCoordinate = state.userGeographicCoordinate ?? bounds.center
                let currentCenterLocation = CLLocation(latitude: bounds.center.latitude, longitude: bounds.center.longitude)
                let isRegionChanged = checkIfRegionChanged(from: state.lastSearchedLocation, to: currentCenterLocation)
                let hasFilter = state.photoBoothListState.filteredBrands.isEmpty == false
                let event = MapAnalyticsEvent.mapReSearch(hasFilter: hasFilter, regionChanged: isRegionChanged)
                state.lastSearchedLocation = currentCenterLocation
                return .merge(
                    .run { _ in analytics.logEvent(event: event) },
                    .send(.fetchPhotoBooths(bounds: bounds)),
                    .send(.fetchNearbyPhotoBooths(nearbyTargetCoordinate))
                )
                
                // MARK: - Data Fetching
            case .loadBrands:
                return .run { send in
                    await send(.brandsResponse(Result { try await photoBoothClient.loadBrands() }))
                }
                
            case let .brandsResponse(.success(brands)):
                state.photoBoothListState.brands = IdentifiedArray(uniqueElements: brands)
                return .none
                
            case let .brandsResponse(.failure(error)):
                // TODO: 토스트
                Logger.presentation.error("브랜드 정보 로드 실패: \(error)")
                return .none
                
            case let .fetchPhotoBooths(bounds):
                state.isSearchHereButtonVisible = false
                state.photoBooths.removeAll()
                
                return .run { send in
                    let stream = try await photoBoothClient.fetchPhotoBooths(bounds: bounds)
                    for await chunk in stream {
                        await send(.photoBoothChunkLoaded(chunk))
                    }
                    await send(.photoBoothStreamFinished)
                } catch: { error, send in
                    await send(.photoBoothStreamFailure(error))
                }.cancellable(id: CancelID.mapFetch, cancelInFlight: true)
                
            case let .photoBoothChunkLoaded(chunk):
                state.photoBooths.append(contentsOf: chunk)
                let isFirstBatch = state.photoBooths.count == chunk.count
                return .send(.processNewChunk(chunk, isFirstBatch: isFirstBatch))
                
            case let .processNewChunk(chunk, isFirstBatch):
                let activeFilters = state.photoBoothListState.filteredBrands
                return .run { send in
                    let filteredChunk: [PhotoBooth]
                    filteredChunk = activeFilters.isEmpty ? chunk : chunk.filter { activeFilters.contains($0.brand) }
                    await send(.appendProcessedChunk(map: filteredChunk, isFirstBatch: isFirstBatch))
                }
                
            case let .appendProcessedChunk(map, isFirstBatch):
                if isFirstBatch {
                    state.visiblePhotoBooths = IdentifiedArray(uniqueElements: map)
                } else {
                    state.visiblePhotoBooths.append(contentsOf: map)
                }
                return .none
                
            case .photoBoothStreamFinished:
                return .none
                
            case let .photoBoothStreamFailure(error):
                Logger.presentation.error("PhotoBooth stream error: \(error)")
                return .none
                
            case let .fetchNearbyPhotoBooths(coordinate):
                state.photoBoothListState.photoBooths.removeAll()
                
                return .run { send in
                    let booths = try await photoBoothClient.fetchNearbyPhotoBooths(coordinate: coordinate)
                    await send(.nearbyPhotoBoothResponse(.success(booths)))
                } catch: { error, send in
                    await send(.nearbyPhotoBoothResponse(.failure(error)))
                }.cancellable(id: CancelID.listFetch, cancelInFlight: true)
                
            case let .nearbyPhotoBoothResponse(.success(booths)):
                let nearbyBooths = IdentifiedArray(uniqueElements: booths)
                return .merge(
                    .send(.photoBoothListAction(.setNearbyBooths(nearbyBooths))),
                    .send(.startBackgroundCalculation)
                )
                
            case let .nearbyPhotoBoothResponse(.failure(error)):
                Logger.presentation.error("Nearby PhotoBooths fetch error: \(error)")
                return .none
                
            case .startBackgroundCalculation:
                let mapBooths = state.photoBooths
                let listBooths = state.photoBoothListState.photoBooths
                let activeFilters = state.photoBoothListState.filteredBrands
                return .run { send in
                    let visibleMapBooths: IdentifiedArrayOf<PhotoBooth>
                    let visibleListBooths: IdentifiedArrayOf<PhotoBooth>
                    visibleMapBooths = activeFilters.isEmpty ? mapBooths : mapBooths.filter { activeFilters.contains($0.brand) }
                    visibleListBooths = activeFilters.isEmpty ? listBooths : listBooths.filter { activeFilters.contains($0.brand) }
                    await send(.didFinishBackgroundCalculation(map: visibleMapBooths, list: visibleListBooths))
                }
                .cancellable(id: CancelID.calculation, cancelInFlight: true)
                
            case let .didFinishBackgroundCalculation(map, list):
                state.visiblePhotoBooths = map
                return .send(.photoBoothListAction(.setVisibleBooths(list)))
                
            case .didTapGoBackToMapButton:
                resetToMapMode(&state, for: .first)
                return .none
                
            case .didTapBooth(let photoBooth):
                state.isUserTrackingMode = false
                selectPhotoBooth(&state, photoBooth: photoBooth)
                let event = MapAnalyticsEvent.boothSelect(brandName: photoBooth.brand.name, entryPoint: .map)
                return .run { _ in analytics.logEvent(event: event) }
                
            case .didTapBoothCard:
                state.isUserTrackingMode = false
                guard let photoBooth = state.selectedBooth else { return .none }
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
                state.isUserTrackingMode = false
                selectPhotoBooth(&state, photoBooth: photoBooth)
                let event = MapAnalyticsEvent.boothSelect(brandName: photoBooth.brand.name, entryPoint: .bottomSheet)
                return .run { _ in analytics.logEvent(event: event) }
                
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
    
    func checkIfRegionChanged(from lastLocation: CLLocation?, to currentLocation: CLLocation) -> Bool {
        guard let lastLocation else { return true }
        return currentLocation.distance(from: lastLocation) >= Constants.regionChangeDistanceThreshold
    }
}
