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
        var isPermissionAlertPresented: Bool = false
        var initialSearchState: MapInitialSearchState = .awaitingPermission
        
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
        var isFavoriteMarkerFilterEnabled: Bool = false
        var favoriteFetchGeneration: Int = .zero
        var pendingFavoriteUpdates: [PhotoBooth.ID: Bool] = [:]
        
        // Child State
        var photoBoothListState = PhotoBoothListFeature.State()
        var photoBoothSearchState = PhotoBoothSearchFeature.State()
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
        case didTapFavorite(PhotoBooth)
        case didTapFavoriteMarkerFilterButton
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
        case attemptInitialSearch
        
        // Map Logic Actions
        case mapLoaded(GeographicBoundingBox)
        case cameraMotionStarted
        case cameraMotionChanged(GeographicBoundingBox)
        case cameraMotionEnded(GeographicBoundingBox)
        case updateSearchButtonVisibility(isVisible: Bool)
        
        // Data Handling Actions
        // Map
        case fetchPhotoBooths(bounds: GeographicBoundingBox)
        case photoBoothChunkLoaded([PhotoBooth])
        case photoBoothStreamFinished
        case photoBoothStreamFailure(Error)
        case updatePhotoBoothFavoriteResponse(photoBooth: PhotoBooth, requestedValue: Bool, Result<Void, Error>)
        case loadBrands
        case brandsResponse(Result<[PhotoBoothBrand], Error>)
        
        // Sheet
        case fetchNearbyPhotoBooths(GeographicCoordinate)
        case nearbyPhotoBoothResponse(Result<[PhotoBooth], Error>)
        case fetchFavoritePhotoBooths(shouldLogViewEvent: Bool)
        case favoritePhotoBoothsResponse(Result<[PhotoBooth], Error>, shouldLogViewEvent: Bool, generation: Int)
        case refreshVisibleMapPhotoBooths
        case didUpdateVisibleMapPhotoBooths(IdentifiedArrayOf<PhotoBooth>)
        case startBackgroundCalculation
        case processNewChunk([PhotoBooth], isFirstBatch: Bool)
        case appendProcessedChunk(map: [PhotoBooth], isFirstBatch: Bool)
        case didFinishBackgroundCalculation(
            map: IdentifiedArrayOf<PhotoBooth>,
            list: IdentifiedArrayOf<PhotoBooth>,
            favoriteList: IdentifiedArrayOf<PhotoBooth>
        )
        case didSelectDirectionApp(DirectionAppType)
        
        // Binding & Child
        case binding(BindingAction<State>)
        case photoBoothListAction(PhotoBoothListFeature.Action)
        case photoBoothSearchAction(PhotoBoothSearchFeature.Action)
        case delegate(Delegate)
        public enum Delegate {
            case showToast(NekiToastItem)
            case routeToBrandReorder(IdentifiedArrayOf<PhotoBoothBrand>)
        }
    }
    
    private enum CancelID: Hashable {
        case mapFetch
        case listFetch
        case locationStream
        case locationAuthorizationStream
        case sdkAuthorizationStream
        case calculation
        case mapMarkerViewportCalculation
        case favoriteFetch
        case favorite(PhotoBooth.ID)
    }
    
    @Dependency(\.mapClient) private var mapClient
    @Dependency(\.photoBoothClient) private var photoBoothClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.openURL) private var openURL
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.photoBoothListState, action: \.photoBoothListAction) { PhotoBoothListFeature() }
        Scope(state: \.photoBoothSearchState, action: \.photoBoothSearchAction) { PhotoBoothSearchFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                
                // MARK: - Life Cycle & Streams
            case .onAppear:
                return .merge(
                    .send(.loadBrands),
                    .send(.fetchFavoritePhotoBooths(shouldLogViewEvent: false)),
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
                    state.initialSearchState = .waitingForUserLocation
                    return .merge(
                        .run { send in
                            for await location in await mapClient.trackingLocation() {
                                await send(.updateUserLocation(.success(location)))
                            }
                        }.cancellable(id: CancelID.locationStream, cancelInFlight: true),
                        .send(.didTapCurrentLocationButton)
                    )
                    
                case .notDetermined:
                    state.initialSearchState = .awaitingPermission
                    return state.locationAuthorizationNeeded ? .send(.requestPermission) : .none
                    
                case .denied, .restricted:
                    state.isUserTrackingMode = false
                    state.initialSearchState = .readyForDefaultLocation
                    updateCameraPosition(&state, to: Constants.defaultInitialPosition.coordinate)
                    return .send(.attemptInitialSearch)
                    
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
                return .merge(
                    .send(.attemptInitialSearch),
                    .send(.startBackgroundCalculation)
                )
                
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
                
                if state.isUserTrackingMode {
                    updateCameraPosition(&state, to: location.coordinate)
                }
                
                guard state.initialSearchState == .waitingForUserLocation else { return .none }
                state.isSearchHereButtonVisible = false
                state.initialSearchState = .readyForUserLocation
                updateCameraPosition(&state, to: location.coordinate)
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

            case let .cameraMotionChanged(bounds):
                state.currentBounds = bounds
                return .send(.refreshVisibleMapPhotoBooths)
                
            case let .cameraMotionEnded(bounds):
                state.currentBounds = bounds
                state.cameraPosition = bounds.center
                return .merge(
                    .send(.attemptInitialSearch),
                    .send(.startBackgroundCalculation)
                )
                
            case let .updateSearchButtonVisibility(isVisible):
                state.isSearchHereButtonVisible = isVisible
                return .none
                
            case .didTapSearchHereButton:
                guard let bounds = state.currentBounds else { return .none }
                let centerCoordinate = bounds.center
                let currentCenterLocation = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
                let isRegionChanged = checkIfRegionChanged(from: state.lastSearchedLocation, to: currentCenterLocation)
                let hasFilter = state.photoBoothListState.filteredBrands.isEmpty == false
                let event = MapAnalyticsEvent.mapReSearch(hasFilter: hasFilter, regionChanged: isRegionChanged)
                state.lastSearchedLocation = currentCenterLocation
                return .merge(
                    .run { _ in await analytics.logEvent(event) },
                    .send(.fetchPhotoBooths(bounds: bounds)),
                    .send(.fetchNearbyPhotoBooths(centerCoordinate))
                )
                
            case .attemptInitialSearch:
                guard let bounds = state.currentBounds else { return .none }
                guard let targetCoordinate = initialSearchTargetCoordinate(for: state) else { return .none }
                
                let currentCameraLocation = CLLocation(latitude: bounds.center.latitude, longitude: bounds.center.longitude)
                let targetLocation = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
                
                guard currentCameraLocation.distance(from: targetLocation) <= Constants.cameraTargetDistanceThreshold else { return .none }
                state.initialSearchState = .completed
                state.lastSearchedLocation = currentCameraLocation
                return .merge(
                    .send(.fetchPhotoBooths(bounds: bounds)),
                    nearbyPhotoBoothsEffect(for: state)
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
                let mapBooths = mapBoothsPreservingFavoriteState(from: chunk, state: state)
                let favoriteBooths = isFirstBatch ? state.photoBoothListState.favoriteBooths : []
                let activeBrandIDs = Self.activeBrandIDs(from: state.photoBoothListState.filteredBrands)
                let currentBounds = state.currentBounds
                let isFavoriteMarkerFilterEnabled = state.isFavoriteMarkerFilterEnabled
                return .run { send in
                    let visibleMapBooths = Self.visibleMapPhotoBooths(
                        mapBooths: mapBooths,
                        favoriteBooths: favoriteBooths,
                        activeBrandIDs: activeBrandIDs,
                        currentBounds: currentBounds,
                        isFavoriteMarkerFilterEnabled: isFavoriteMarkerFilterEnabled
                    )
                    await send(.appendProcessedChunk(map: Array(visibleMapBooths), isFirstBatch: isFirstBatch))
                }
                
            case let .appendProcessedChunk(map, isFirstBatch):
                var mergedMap: [PhotoBooth] = []
                mergedMap.reserveCapacity(map.count)
                map.forEach { mergedMap.append(photoBoothPreservingFavoriteState($0, state: state)) }

                if isFirstBatch {
                    state.visiblePhotoBooths = IdentifiedArray(uniqueElements: mergedMap)
                } else {
                    mergedMap.forEach { photoBooth in
                        if state.visiblePhotoBooths[id: photoBooth.id] != nil { state.visiblePhotoBooths[id: photoBooth.id] = photoBooth }
                        else { state.visiblePhotoBooths.append(photoBooth) }
                    }
                }
                return .none
                
            case .photoBoothStreamFinished:
                return .none
                
            case let .photoBoothStreamFailure(error):
                Logger.presentation.error("PhotoBooth stream error: \(error)")
                return .none
                
            case let .didTapFavorite(photoBooth):
                let requestedValue = photoBooth.isFavorite == false
                state.favoriteFetchGeneration += 1
                state.pendingFavoriteUpdates[photoBooth.id] = requestedValue
                updatePhotoBoothFavoriteState(&state, photoBooth: photoBooth, isFavorite: requestedValue)

                let stateEffect: Effect<Action> = .send(.startBackgroundCalculation)
                let cancelFavoriteFetchEffect: Effect<Action> = .cancel(id: CancelID.favoriteFetch)
                let requestEffect: Effect<Action> = .run { [id = photoBooth.id, requestedValue] send in
                    await send(.updatePhotoBoothFavoriteResponse(
                        photoBooth: photoBooth,
                        requestedValue: requestedValue,
                        Result { try await photoBoothClient.updatePhotoBoothFavorite(id, requestedValue) }
                    ))
                }
                .cancellable(id: CancelID.favorite(photoBooth.id), cancelInFlight: true)
                
                return .merge(stateEffect, cancelFavoriteFetchEffect, requestEffect)

            case let .updatePhotoBoothFavoriteResponse(photoBooth, requestedValue, .success):
                state.pendingFavoriteUpdates[photoBooth.id] = nil
                updatePhotoBoothFavoriteState(&state, photoBooth: photoBooth, isFavorite: requestedValue)
                let message = requestedValue
                    ? "저장한 포토부스에 추가했어요!"
                    : "저장한 포토부스에서 삭제했어요!"
                let event: MapAnalyticsEvent = requestedValue
                    ? .boothFavoriteAdd(boothName: photoBooth.name, brandName: photoBooth.brand.name)
                    : .boothFavoriteRemove(boothName: photoBooth.name, brandName: photoBooth.brand.name)
                return .merge(
                    .send(.startBackgroundCalculation),
                    .send(.delegate(.showToast(NekiToastItem(message, style: .success)))),
                    .run { _ in await analytics.logEvent(event) }
                )

            case let .updatePhotoBoothFavoriteResponse(photoBooth, requestedValue, .failure(error)):
                if error is CancellationError { return .none }
                Logger.presentation.error("PhotoBooth favorite update error: \(error)")
                state.pendingFavoriteUpdates[photoBooth.id] = nil
                updatePhotoBoothFavoriteState(&state, photoBooth: photoBooth, isFavorite: requestedValue == false)
                return .send(.startBackgroundCalculation)

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

            case let .fetchFavoritePhotoBooths(shouldLogViewEvent):
                state.favoriteFetchGeneration += 1
                let generation = state.favoriteFetchGeneration
                return .run { send in
                    await send(.favoritePhotoBoothsResponse(
                        Result { try await photoBoothClient.fetchFavoritePhotoBooths() },
                        shouldLogViewEvent: shouldLogViewEvent,
                        generation: generation
                    ))
                }
                .cancellable(id: CancelID.favoriteFetch, cancelInFlight: true)

            case let .favoritePhotoBoothsResponse(.success(photoBooths), shouldLogViewEvent, generation):
                guard generation == state.favoriteFetchGeneration else { return .none }
                let favoriteBooths = mergedFavoriteBooths(from: photoBooths, state: state)
                let favoriteBoothCount = favoriteBooths.count
                let viewEventEffect: Effect<Action> = shouldLogViewEvent
                    ? .run { _ in await analytics.logEvent(MapAnalyticsEvent.favoriteBoothView(favoriteBoothCount: favoriteBoothCount)) }
                    : .none
                return .merge(
                    .send(.photoBoothListAction(.setFavoriteBooths(favoriteBooths))),
                    .send(.photoBoothListAction(.setFavoriteBoothCount(favoriteBoothCount))),
                    .send(.startBackgroundCalculation),
                    viewEventEffect
                )
                
            case let .favoritePhotoBoothsResponse(.failure(error), _, generation):
                guard generation == state.favoriteFetchGeneration else { return .none }
                Logger.presentation.error("Favorite PhotoBooths fetch error: \(error)")
                return .none

            case .refreshVisibleMapPhotoBooths:
                let mapBooths = state.photoBooths
                let favoriteBooths = state.photoBoothListState.favoriteBooths
                let activeBrandIDs = Self.activeBrandIDs(from: state.photoBoothListState.filteredBrands)
                let currentBounds = state.currentBounds
                let isFavoriteMarkerFilterEnabled = state.isFavoriteMarkerFilterEnabled
                return .run { send in
                    let visibleMapBooths = Self.visibleMapPhotoBooths(
                        mapBooths: mapBooths,
                        favoriteBooths: favoriteBooths,
                        activeBrandIDs: activeBrandIDs,
                        currentBounds: currentBounds,
                        isFavoriteMarkerFilterEnabled: isFavoriteMarkerFilterEnabled
                    )
                    await send(.didUpdateVisibleMapPhotoBooths(visibleMapBooths))
                }
                .cancellable(id: CancelID.mapMarkerViewportCalculation, cancelInFlight: true)

            case let .didUpdateVisibleMapPhotoBooths(photoBooths):
                state.visiblePhotoBooths = photoBooths
                return .none

            case .startBackgroundCalculation:
                let mapBooths = state.photoBooths
                let listBooths = state.photoBoothListState.photoBooths
                let favoriteBooths = state.photoBoothListState.favoriteBooths
                let activeBrandIDs = Self.activeBrandIDs(from: state.photoBoothListState.filteredBrands)
                let isFavoriteMarkerFilterEnabled = state.isFavoriteMarkerFilterEnabled
                let currentBounds = state.currentBounds
                return .run { send in
                    let visibleMapBooths: IdentifiedArrayOf<PhotoBooth>
                    let visibleListBooths: IdentifiedArrayOf<PhotoBooth>
                    let visibleFavoriteBooths: IdentifiedArrayOf<PhotoBooth>
                    visibleMapBooths = Self.visibleMapPhotoBooths(
                        mapBooths: mapBooths,
                        favoriteBooths: favoriteBooths,
                        activeBrandIDs: activeBrandIDs,
                        currentBounds: currentBounds,
                        isFavoriteMarkerFilterEnabled: isFavoriteMarkerFilterEnabled
                    )
                    visibleListBooths = Self.visibleListPhotoBooths(listBooths, activeBrandIDs: activeBrandIDs)
                    visibleFavoriteBooths = Self.visibleFavoritePhotoBooths(favoriteBooths, activeBrandIDs: activeBrandIDs)
                    await send(.didFinishBackgroundCalculation(map: visibleMapBooths, list: visibleListBooths, favoriteList: visibleFavoriteBooths))
                }
                .cancellable(id: CancelID.calculation, cancelInFlight: true)
                
            case let .didFinishBackgroundCalculation(map, list, favoriteList):
                state.visiblePhotoBooths = map
                return .merge(
                    .send(.photoBoothListAction(.setVisibleBooths(list))),
                    .send(.photoBoothListAction(.setVisibleFavoriteBooths(favoriteList)))
                )
                
            case .didTapGoBackToMapButton:
                resetToMapMode(&state, for: .first)
                return .none
                
            case .didTapBooth(let photoBooth):
                state.isUserTrackingMode = false
                selectPhotoBooth(&state, photoBooth: photoBooth)
                let event = MapAnalyticsEvent.boothSelect(brandName: photoBooth.brand.name, entryPoint: .map)
                return .run { _ in await analytics.logEvent(event) }
                
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
                
            case .didTapFavoriteMarkerFilterButton:
                state.isFavoriteMarkerFilterEnabled.toggle()
                let favoriteBoothCount = state.photoBoothListState.favoriteBoothCount
                let event: MapAnalyticsEvent = state.isFavoriteMarkerFilterEnabled
                    ? .favoriteBoothFilterOn(favoriteBoothCount: favoriteBoothCount)
                    : .favoriteBoothFilterOff
                return .merge(
                    .send(.startBackgroundCalculation),
                    .run { _ in await analytics.logEvent(event) }
                )
                
            case let .didSelectDirectionApp(appType):
                guard let photoBooth = state.directionSheetPhotoBooth else { return .none }
                guard let url = appType.connectLink(coordinate: photoBooth.coordinate, name: photoBooth.name) else { return .none }
                state.directionSheetPhotoBooth = nil
                return .merge(
                    .run { _ in await analytics.logEvent(MapAnalyticsEvent.mapRouteClick(mapType: appType)) },
                    .run { _ in await openURL(url) }
                )
                
            case .updateSDKAuthStatus(let isAuthorized):
                state.isSDKAuthSuccessful = isAuthorized
                return .none
                
            case .photoBoothListAction(.selectFilterOption):
                return .send(.startBackgroundCalculation)

            case let .photoBoothListAction(.selectTab(tab)):
                switch tab {
                case .nearby:
                    return .none
                case .favorite:
                    state.photoBoothListState.filteredBrands.removeAll()
                    return .merge(
                        .send(.fetchFavoritePhotoBooths(shouldLogViewEvent: true)),
                        .send(.startBackgroundCalculation)
                    )
                }

            case let .photoBoothListAction(.delegate(.didTapFavorite(photoBooth))):
                return .send(.didTapFavorite(photoBooth))

            case .photoBoothListAction(.delegate(.didTapBrandReorderButton)):
                return .send(.delegate(.routeToBrandReorder(state.photoBoothListState.brands)))

            case let .photoBoothListAction(.didTapBooth(photoBooth)):
                state.isUserTrackingMode = false
                selectPhotoBooth(&state, photoBooth: photoBooth)
                let event = MapAnalyticsEvent.boothSelect(brandName: photoBooth.brand.name, entryPoint: .bottomSheet)
                return .run { _ in await analytics.logEvent(event) }
                
            default:
                return .none
            }
        }
    }
}


// MARK: - MapFeature + Effect Handlers

private extension MapFeature {
    func mergedFavoriteBooths(from fetchedPhotoBooths: [PhotoBooth], state: State) -> IdentifiedArrayOf<PhotoBooth> {
        var favoriteBooths = IdentifiedArrayOf<PhotoBooth>()

        for photoBooth in fetchedPhotoBooths {
            guard state.pendingFavoriteUpdates[photoBooth.id] != false else { continue }
            var favoriteBooth = photoBooth
            favoriteBooth.isFavorite = true
            favoriteBooths.append(favoriteBooth)
        }

        for (id, isFavorite) in state.pendingFavoriteUpdates {
            guard isFavorite else {
                favoriteBooths.remove(id: id)
                continue
            }
            guard var photoBooth = self.photoBooth(id: id, state: state) else { continue }
            photoBooth.isFavorite = true
            if favoriteBooths[id: id] != nil { favoriteBooths[id: id] = photoBooth }
            else { favoriteBooths.insert(photoBooth, at: .zero) }
        }

        return favoriteBooths
    }

    func photoBooth(id: PhotoBooth.ID, state: State) -> PhotoBooth? {
        let selectedBooth = state.selectedBooth?.id == id ? state.selectedBooth : nil
        return selectedBooth ??
            state.photoBooths[id: id] ??
            state.visiblePhotoBooths[id: id] ??
            state.photoBoothListState.photoBooths[id: id] ??
            state.photoBoothListState.visibleBooths[id: id] ??
            state.photoBoothListState.favoriteBooths[id: id] ??
            state.photoBoothListState.visibleFavoriteBooths[id: id]
    }

    func currentFavoriteState(for id: PhotoBooth.ID, state: State) -> Bool? {
        if let pendingFavoriteState = state.pendingFavoriteUpdates[id] { return pendingFavoriteState }
        if state.selectedBooth?.id == id { return state.selectedBooth?.isFavorite }
        if let visiblePhotoBooth = state.visiblePhotoBooths[id: id] { return visiblePhotoBooth.isFavorite }
        if let listPhotoBooth = state.photoBoothListState.photoBooths[id: id] { return listPhotoBooth.isFavorite }
        if let visibleListPhotoBooth = state.photoBoothListState.visibleBooths[id: id] { return visibleListPhotoBooth.isFavorite }
        if let favoritePhotoBooth = state.photoBoothListState.favoriteBooths[id: id] { return favoritePhotoBooth.isFavorite }
        if let visibleFavoritePhotoBooth = state.photoBoothListState.visibleFavoriteBooths[id: id] { return visibleFavoritePhotoBooth.isFavorite }
        if let photoBooth = state.photoBooths[id: id] { return photoBooth.isFavorite }
        return nil
    }

    func photoBoothPreservingFavoriteState(_ photoBooth: PhotoBooth, state: State) -> PhotoBooth {
        guard let isFavorite = currentFavoriteState(for: photoBooth.id, state: state) else { return photoBooth }
        var updatedPhotoBooth = photoBooth
        updatedPhotoBooth.isFavorite = isFavorite
        return updatedPhotoBooth
    }

    func mapBoothsPreservingFavoriteState(from chunk: [PhotoBooth], state: State) -> IdentifiedArrayOf<PhotoBooth> {
        var photoBooths: [PhotoBooth] = []
        photoBooths.reserveCapacity(chunk.count)
        chunk.forEach { photoBooths.append(photoBoothPreservingFavoriteState($0, state: state)) }
        return IdentifiedArray(uniqueElements: photoBooths)
    }

    static func visibleMapPhotoBooths(
        mapBooths: IdentifiedArrayOf<PhotoBooth>,
        favoriteBooths: IdentifiedArrayOf<PhotoBooth>,
        activeBrandIDs: Set<PhotoBoothBrand.ID>,
        currentBounds: GeographicBoundingBox?,
        isFavoriteMarkerFilterEnabled: Bool
    ) -> IdentifiedArrayOf<PhotoBooth> {
        var visibleBooths: [PhotoBooth] = []
        var visibleIndexByID: [PhotoBooth.ID: Int] = [:]
        let estimatedCapacity = isFavoriteMarkerFilterEnabled ? favoriteBooths.count : mapBooths.count + favoriteBooths.count
        visibleBooths.reserveCapacity(estimatedCapacity)
        visibleIndexByID.reserveCapacity(estimatedCapacity)

        if isFavoriteMarkerFilterEnabled == false {
            for photoBooth in mapBooths {
                guard isActiveBrand(photoBooth.brand, activeBrandIDs: activeBrandIDs) else { continue }
                visibleIndexByID[photoBooth.id] = visibleBooths.count
                visibleBooths.append(photoBooth)
            }
        }

        guard let currentBounds else { return IdentifiedArray(uniqueElements: visibleBooths) }

        for photoBooth in favoriteBooths {
            guard photoBooth.isFavorite else { continue }
            guard currentBounds.contains(photoBooth.coordinate) else { continue }
            guard isActiveBrand(photoBooth.brand, activeBrandIDs: activeBrandIDs) else { continue }

            if let index = visibleIndexByID[photoBooth.id] {
                visibleBooths[index] = photoBooth
            } else {
                visibleIndexByID[photoBooth.id] = visibleBooths.count
                visibleBooths.append(photoBooth)
            }
        }

        return IdentifiedArray(uniqueElements: visibleBooths)
    }

    static func visibleListPhotoBooths(
        _ photoBooths: IdentifiedArrayOf<PhotoBooth>,
        activeBrandIDs: Set<PhotoBoothBrand.ID>
    ) -> IdentifiedArrayOf<PhotoBooth> {
        guard activeBrandIDs.isEmpty == false else { return photoBooths }
        return photoBooths.filter { activeBrandIDs.contains($0.brand.id) }
    }

    static func visibleFavoritePhotoBooths(
        _ photoBooths: IdentifiedArrayOf<PhotoBooth>,
        activeBrandIDs: Set<PhotoBoothBrand.ID>
    ) -> IdentifiedArrayOf<PhotoBooth> {
        guard activeBrandIDs.isEmpty == false else { return photoBooths.filter(\.isFavorite) }
        return photoBooths.filter { $0.isFavorite && activeBrandIDs.contains($0.brand.id) }
    }

    static func activeBrandIDs(from brands: Set<PhotoBoothBrand>) -> Set<PhotoBoothBrand.ID> {
        guard brands.isEmpty == false else { return [] }
        var activeBrandIDs = Set<PhotoBoothBrand.ID>()
        activeBrandIDs.reserveCapacity(brands.count)
        brands.forEach { activeBrandIDs.insert($0.id) }
        return activeBrandIDs
    }

    static func isActiveBrand(_ brand: PhotoBoothBrand, activeBrandIDs: Set<PhotoBoothBrand.ID>) -> Bool {
        activeBrandIDs.isEmpty || activeBrandIDs.contains(brand.id)
    }

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
    
    func updatePhotoBoothFavoriteState(_ state: inout State, photoBooth: PhotoBooth, isFavorite: Bool) {
        let id = photoBooth.id
        var updatedPhotoBooth = self.photoBooth(id: id, state: state) ?? photoBooth
        updatedPhotoBooth.isFavorite = isFavorite

        if state.selectedBooth?.id == id {
            state.selectedBooth?.isFavorite = isFavorite
        }

        state.photoBooths[id: id]?.isFavorite = isFavorite
        state.visiblePhotoBooths[id: id]?.isFavorite = isFavorite
        state.photoBoothListState.photoBooths[id: id]?.isFavorite = isFavorite
        state.photoBoothListState.visibleBooths[id: id]?.isFavorite = isFavorite

        updateFavoriteBoothList(&state.photoBoothListState, with: updatedPhotoBooth)
        updateFavoriteBoothCount(&state.photoBoothListState)
    }

    func updateFavoriteBoothList(_ state: inout PhotoBoothListFeature.State, with photoBooth: PhotoBooth) {
        guard photoBooth.isFavorite else {
            state.favoriteBooths.remove(id: photoBooth.id)
            state.visibleFavoriteBooths.remove(id: photoBooth.id)
            return
        }

        if state.favoriteBooths[id: photoBooth.id] != nil {
            state.favoriteBooths[id: photoBooth.id] = photoBooth
        } else {
            state.favoriteBooths.insert(photoBooth, at: .zero)
        }
        
        if state.visibleFavoriteBooths[id: photoBooth.id] != nil {
            state.visibleFavoriteBooths[id: photoBooth.id] = photoBooth
        } else if state.filteredBrands.isEmpty || state.filteredBrands.contains(photoBooth.brand) {
            state.visibleFavoriteBooths.insert(photoBooth, at: .zero)
        }
    }
    
    func updateFavoriteBoothCount(_ state: inout PhotoBoothListFeature.State) {
        state.favoriteBoothCount = state.favoriteBooths.count
    }

    func updateCameraPosition(_ state: inout State, to coordinate: CLLocationCoordinate2D) {
        state.cameraPosition = .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    func checkIfRegionChanged(from lastLocation: CLLocation?, to currentLocation: CLLocation) -> Bool {
        guard let lastLocation else { return false }
        return currentLocation.distance(from: lastLocation) >= Constants.regionChangeDistanceThreshold
    }
    
    func initialSearchTargetCoordinate(for state: State) -> GeographicCoordinate? {
        switch state.initialSearchState {
        case .awaitingPermission, .waitingForUserLocation, .completed:
            return nil
        case .readyForDefaultLocation:
            return .init(
                latitude: Constants.defaultInitialPosition.coordinate.latitude,
                longitude: Constants.defaultInitialPosition.coordinate.longitude
            )
        case .readyForUserLocation:
            return state.userGeographicCoordinate
        }
    }
    
    func nearbyPhotoBoothsEffect(for state: State) -> Effect<Action> {
        guard let userGeographicCoordinate = state.userGeographicCoordinate else {
            let emptyBooths = IdentifiedArrayOf<PhotoBooth>()
            return .merge(
                .send(.photoBoothListAction(.setNearbyBooths(emptyBooths))),
                .send(.photoBoothListAction(.setVisibleBooths(emptyBooths)))
            )
        }
        
        return .send(.fetchNearbyPhotoBooths(userGeographicCoordinate))
    }
}
