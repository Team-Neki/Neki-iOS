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

    struct PhotoBoothFetchContext: Equatable {
        private(set) var generation: UInt = .zero
        private(set) var bounds: GeographicBoundingBox?
        private(set) var hasReceivedChunk: Bool = false

        mutating func begin(in bounds: GeographicBoundingBox) -> UInt {
            generation &+= 1
            self.bounds = bounds
            hasReceivedChunk = false
            return generation
        }

        mutating func markChunkReceived() { hasReceivedChunk = true }

        mutating func finish() {
            bounds = nil
            hasReceivedChunk = false
        }

        mutating func invalidate() {
            generation &+= 1
            finish()
        }

        func isCurrent(_ generation: UInt) -> Bool { bounds != nil && self.generation == generation }
    }
    
    @ObservableState
    public struct State {
        // UI Control
        var isSDKAuthSuccessful: Bool = false
        var detent: NekiSheetDetent = SheetStage.first.detent
        var isExploreHereButtonVisible: Bool = false
        var isSearchPresented: Bool = false
        /// 지도에 반영 중인 검색어입니다. 검색 결과를 보고 있지 않으면 `nil`입니다.
        ///
        /// 상단 검색 필드를 검색 완료 형태로 유지하고, 검색 화면으로 되돌아갈 때 그대로 다시 검색합니다.
        var appliedSearchQuery: PhotoBoothSearchQuery?
        var isPermissionAlertPresented: Bool = false
        var initialExplorationState: MapInitialExplorationState = .awaitingPermission
        
        // Map State
        var cameraPosition: GeographicCoordinate?
        /// 카메라를 한 지점이 아니라 특정 영역에 맞춰야 할 때 담는 영역입니다.
        ///
        /// 검색 결과처럼 여러 지점을 한 화면에 담아야 하는 경우에 씁니다.
        /// 한 지점으로 옮기는 ``cameraPosition``과 동시에 채우지 않습니다.
        var cameraFitBounds: GeographicBoundingBox?
        var currentBounds: GeographicBoundingBox?
        var lastExploredLocation: CLLocation?
        
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
        var photoBoothFetchContext = PhotoBoothFetchContext()
        
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
        case didTapExploreHereButton
        /// 검색으로 지도가 옮겨진 상태에서 상단 컨트롤을 눌렀을 때입니다.
        case didTapSearchResultMapControl
        case didTapSearchField
        case didTapClearSearchButton
        case dismissPermissionAlert
        
        // Internal Logic Actions
        case updateLocationAuthorization(CLAuthorizationStatus)
        case updateSDKAuthStatus(Bool)
        case updateUserLocation(Result<CLLocation, Error>)
        case setUserTrackingMode(Bool)
        case didDetectMapInteraction
        case presentPermissionAlert
        case attemptInitialExploration
        
        // Map Logic Actions
        case mapLoaded(GeographicBoundingBox)
        case cameraMotionStarted
        case cameraMotionChanged(GeographicBoundingBox)
        case cameraMotionEnded(GeographicBoundingBox)
        case updateExploreButtonVisibility(isVisible: Bool)
        
        // Data Handling Actions
        // Map
        case fetchPhotoBooths(bounds: GeographicBoundingBox)
        case photoBoothChunkLoaded([PhotoBooth], generation: UInt)
        case photoBoothStreamFinished(generation: UInt)
        case photoBoothStreamFailure(Error, generation: UInt)
        case updatePhotoBoothFavoriteResponse(photoBooth: PhotoBooth, requestedValue: Bool, Result<Void, Error>)
        case loadBrands
        case brandsResponse(Result<[PhotoBoothBrand], Error>)
        
        // Sheet
        case fetchFavoritePhotoBooths(shouldLogViewEvent: Bool)
        case favoritePhotoBoothsResponse(Result<[PhotoBooth], Error>, shouldLogViewEvent: Bool, generation: Int)
        case refreshVisibleMapPhotoBooths
        case didUpdateVisibleMapPhotoBooths(IdentifiedArrayOf<PhotoBooth>)
        case startBackgroundCalculation
        case processNewChunk([PhotoBooth], includesFavoriteBooths: Bool, generation: UInt)
        case appendProcessedChunk(map: [PhotoBooth], list: [PhotoBooth], generation: UInt)
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
        case mapChunkProcessing
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
                    state.initialExplorationState = .waitingForUserLocation
                    return .merge(
                        .run { send in
                            for await location in await mapClient.trackingLocation() {
                                await send(.updateUserLocation(.success(location)))
                            }
                        }.cancellable(id: CancelID.locationStream, cancelInFlight: true),
                        .send(.didTapCurrentLocationButton)
                    )
                    
                case .notDetermined:
                    state.initialExplorationState = .awaitingPermission
                    return state.locationAuthorizationNeeded ? .send(.requestPermission) : .none
                    
                case .denied, .restricted:
                    state.isUserTrackingMode = false
                    state.initialExplorationState = .readyForDefaultLocation
                    updateCameraPosition(&state, to: Constants.defaultInitialPosition.coordinate)
                    // 위치에 동의하지 않으면 검색 결과에 거리를 노출하지 않습니다.
                    return .merge(
                        .send(.attemptInitialExploration),
                        .send(.photoBoothSearchAction(.setUserCoordinate(nil)))
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
                return .merge(
                    .send(.attemptInitialExploration),
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
                // 검색 결과의 거리 표기가 현재 위치를 따라가도록 기준 좌표를 넘깁니다.
                let syncSearchCoordinate = Effect<Action>.send(
                    .photoBoothSearchAction(.setUserCoordinate(state.userGeographicCoordinate))
                )
                
                if state.isUserTrackingMode {
                    updateCameraPosition(&state, to: location.coordinate)
                }
                
                guard state.initialExplorationState == .waitingForUserLocation else { return syncSearchCoordinate }
                state.isExploreHereButtonVisible = false
                state.initialExplorationState = .readyForUserLocation
                updateCameraPosition(&state, to: location.coordinate)
                return syncSearchCoordinate
                
            case .updateUserLocation(.failure):
                state.isUserTrackingMode = false
                return .none
                
            case let .setUserTrackingMode(isUserTrackingMode):
                state.isUserTrackingMode = isUserTrackingMode
                return .none
                
                // MARK: - Map Camera & Exploration Logic
            case .didDetectMapInteraction:
                state.isUserTrackingMode = false
                state.photoBoothFetchContext.invalidate()
                return .merge(
                    .cancel(id: CancelID.mapFetch),
                    .cancel(id: CancelID.mapChunkProcessing),
                    .cancel(id: CancelID.calculation)
                )
                
            case .cameraMotionStarted:
                return .send(.updateExploreButtonVisibility(isVisible: true))

            case let .cameraMotionChanged(bounds):
                state.currentBounds = bounds
                return .send(.refreshVisibleMapPhotoBooths)
                
            case let .cameraMotionEnded(bounds):
                state.currentBounds = bounds
                state.cameraPosition = bounds.center
                return .merge(
                    .send(.attemptInitialExploration),
                    .send(.startBackgroundCalculation)
                )
                
            case let .updateExploreButtonVisibility(isVisible):
                state.isExploreHereButtonVisible = isVisible
                return .none
                
            case .didTapSearchField:
                state.isSearchPresented = true
                // 지도에 반영 중인 검색이 있으면 그 검색어로 되돌려 후보 목록부터 다시 보여 줍니다.
                // 화면이 뜨기 전에 검색어가 자리해야 검색 완료 형태로 열리므로 이펙트로 미루지 않습니다.
                guard let query = state.appliedSearchQuery else { return .none }
                state.photoBoothSearchState.searchText = query.rawValue
                return .send(.photoBoothSearchAction(.beginSearch(query)))

            case .didTapClearSearchButton:
                // 검색을 끝내면 검색 결과를 지우고 다시 지도 영역을 조회해 이 지역 목록으로 돌아갑니다.
                clearAppliedSearch(&state)
                resetToMapMode(&state, for: .second)
                guard let bounds = state.currentBounds else { return .none }
                return .send(.fetchPhotoBooths(bounds: bounds))

            case .didTapSearchResultMapControl:
                // TODO: 검색으로 지도가 옮겨진 상태의 상단 컨트롤 동작 정의 필요.
                // 노출 문구는 "결과 더보기"로 확정했고 동작만 남았습니다.
                // 지도가 검색 때문에 옮겨졌는지는 `state.appliedSearchQuery`로 구분합니다.
                // 이 지역 재탐색(`didTapExploreHereButton`)은 영역 조회로 검색 결과를 지우므로
                // 그대로 재사용할 수 없습니다.
                return .none

            case .didTapExploreHereButton:
                guard let bounds = state.currentBounds else { return .none }
                let centerCoordinate = bounds.center
                let currentCenterLocation = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
                let isRegionChanged = checkIfRegionChanged(from: state.lastExploredLocation, to: currentCenterLocation)
                let hasFilter = state.photoBoothListState.filteredBrands.isEmpty == false
                let event = MapAnalyticsEvent.mapReExplore(hasFilter: hasFilter, regionChanged: isRegionChanged)
                state.lastExploredLocation = currentCenterLocation
                return .merge(
                    .run { _ in await analytics.logEvent(event) },
                    .send(.fetchPhotoBooths(bounds: bounds))
                )
                
            case .attemptInitialExploration:
                // 검색 결과를 보고 있으면 사용자가 고른 범위를 뒤늦은 초기 탐색이 덮지 않도록 여기서 끝냅니다.
                guard state.appliedSearchQuery == nil else {
                    state.initialExplorationState = .completed
                    return .none
                }
                guard let bounds = state.currentBounds else { return .none }
                guard let targetCoordinate = initialExplorationTargetCoordinate(for: state) else { return .none }
                
                let currentCameraLocation = CLLocation(latitude: bounds.center.latitude, longitude: bounds.center.longitude)
                let targetLocation = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
                
                guard currentCameraLocation.distance(from: targetLocation) <= Constants.cameraTargetDistanceThreshold else { return .none }
                state.initialExplorationState = .completed
                state.lastExploredLocation = currentCameraLocation
                return .send(.fetchPhotoBooths(bounds: bounds))
                
                // MARK: - Data Fetching
            case .loadBrands:
                return .run { send in
                    await send(.brandsResponse(Result { try await photoBoothClient.loadBrands() }))
                }
                
            case let .brandsResponse(.success(brands)):
                return .send(.photoBoothListAction(.setBrands(IdentifiedArray(uniqueElements: brands))))
                
            case let .brandsResponse(.failure(error)):
                // TODO: 토스트
                Logger.presentation.error("브랜드 정보 로드 실패: \(error)")
                return .none

            case let .fetchPhotoBooths(bounds):
                state.isExploreHereButtonVisible = false
                // 영역 조회는 검색 결과를 대신하므로 검색어와 좁혀 둔 필터 칩을 함께 되돌립니다.
                clearAppliedSearch(&state)
                let generation = state.photoBoothFetchContext.begin(in: bounds)

                let fetchEffect: Effect<Action> = .run { send in
                    let stream = try await photoBoothClient.fetchPhotoBooths(bounds: bounds)
                    for try await chunk in stream {
                        try Task.checkCancellation()
                        await send(.photoBoothChunkLoaded(chunk, generation: generation))
                    }
                    try Task.checkCancellation()
                    await send(.photoBoothStreamFinished(generation: generation))
                } catch: { error, send in
                    guard (error is CancellationError) == false else { return }
                    await send(.photoBoothStreamFailure(error, generation: generation))
                }.cancellable(id: CancelID.mapFetch, cancelInFlight: true)

                return .concatenate(
                    .merge(
                        .cancel(id: CancelID.mapChunkProcessing),
                        .cancel(id: CancelID.calculation)
                    ),
                    fetchEffect
                )

            case let .photoBoothChunkLoaded(chunk, generation):
                guard state.photoBoothFetchContext.isCurrent(generation) else { return .none }
                let isFirstBatch = state.photoBoothFetchContext.hasReceivedChunk == false
                state.photoBoothFetchContext.markChunkReceived()
                if isFirstBatch {
                    state.photoBooths = IdentifiedArray(uniqueElements: chunk)
                    state.visiblePhotoBooths = []
                    state.photoBoothListState.visibleBooths = []
                } else {
                    state.photoBooths.append(contentsOf: chunk)
                }
                return .send(.processNewChunk(chunk, includesFavoriteBooths: isFirstBatch, generation: generation))

            case let .processNewChunk(chunk, includesFavoriteBooths, generation):
                guard state.photoBoothFetchContext.generation == generation else { return .none }
                let mapBooths = mapBoothsPreservingFavoriteState(from: chunk, state: state)
                let favoriteBooths = includesFavoriteBooths ? state.photoBoothListState.favoriteBooths : []
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
                    let visibleListBooths = Self.visibleListPhotoBooths(mapBooths, activeBrandIDs: activeBrandIDs)
                    guard Task.isCancelled == false else { return }
                    await send(.appendProcessedChunk(
                        map: Array(visibleMapBooths),
                        list: Array(visibleListBooths),
                        generation: generation
                    ))
                }
                .cancellable(id: CancelID.mapChunkProcessing)

            case let .appendProcessedChunk(map, list, generation):
                guard state.photoBoothFetchContext.generation == generation else { return .none }
                var mergedMap: [PhotoBooth] = []
                mergedMap.reserveCapacity(map.count)
                map.forEach { mergedMap.append(photoBoothPreservingFavoriteState($0, state: state)) }
                var mergedList: [PhotoBooth] = []
                mergedList.reserveCapacity(list.count)
                list.forEach { mergedList.append(photoBoothPreservingFavoriteState($0, state: state)) }

                mergedMap.forEach { photoBooth in
                    if state.visiblePhotoBooths[id: photoBooth.id] != nil { state.visiblePhotoBooths[id: photoBooth.id] = photoBooth }
                    else { state.visiblePhotoBooths.append(photoBooth) }
                }
                mergedList.forEach { photoBooth in
                    if state.photoBoothListState.visibleBooths[id: photoBooth.id] != nil { state.photoBoothListState.visibleBooths[id: photoBooth.id] = photoBooth }
                    else { state.photoBoothListState.visibleBooths.append(photoBooth) }
                }
                return .none

            case let .photoBoothStreamFinished(generation):
                guard state.photoBoothFetchContext.isCurrent(generation) else { return .none }
                guard state.photoBoothFetchContext.hasReceivedChunk else {
                    state.photoBooths = []
                    state.photoBoothFetchContext.finish()
                    return .send(.startBackgroundCalculation)
                }
                state.photoBoothFetchContext.finish()
                return .none

            case let .photoBoothStreamFailure(error, generation):
                guard state.photoBoothFetchContext.isCurrent(generation) else { return .none }
                Logger.presentation.error("PhotoBooth stream error: \(error)")
                state.photoBoothFetchContext.finish()
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
                    visibleListBooths = Self.visibleListPhotoBooths(mapBooths, activeBrandIDs: activeBrandIDs)
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
                return .concatenate(
                    .cancel(id: CancelID.mapChunkProcessing),
                    .send(.startBackgroundCalculation)
                )

            case let .photoBoothListAction(.selectTab(tab)):
                switch tab {
                case .nearby:
                    return .none
                case .favorite:
                    return .concatenate(
                        .send(.photoBoothListAction(.clearFilterOptions)),
                        .merge(
                            .send(.fetchFavoritePhotoBooths(shouldLogViewEvent: true)),
                            .send(.startBackgroundCalculation)
                        )
                    )
                }

            case let .photoBoothListAction(.delegate(.didTapFavorite(photoBooth))):
                return .send(.didTapFavorite(photoBooth))

            case .photoBoothSearchAction(.dismissSearch):
                state.isSearchPresented = false
                return .none

            case let .photoBoothSearchAction(.delegate(.didSelectSearchResult(candidate, result))):
                state.isSearchPresented = false
                state.isUserTrackingMode = false
                // 결과를 보는 동안 상단 검색 필드에 검색어를 검색 완료 형태로 남깁니다.
                state.appliedSearchQuery = state.photoBoothSearchState.query
                let photoBooths = result.photoBooths

                // 부스를 직접 고르면 추가 조회 없이 그 지점만 선택합니다. 나머지 마커는 그대로 둡니다.
                // 지도에 한 지점만 찍는 경로라 필터 칩도 그대로 둡니다.
                if case let .photoBooth(photoBooth) = candidate {
                    selectPhotoBooth(&state, photoBooth: photoBooth)
                    if state.photoBooths[id: photoBooth.id] == nil {
                        state.photoBooths.append(photoBooth)
                    }
                    return .merge(
                        .send(.photoBoothSearchAction(.dismissSearch)),
                        .send(.startBackgroundCalculation)
                    )
                }

                // 지역과 지하철역은 응답 자체가 지도에 그릴 목록이므로 영역 조회를 대신합니다.
                // 서버가 보여 줄 영역을 주지 않아 목록으로 직접 정하며, 0건이면 지도를 옮기지 않습니다.
                resetToMapMode(&state, for: .second)
                state.cameraFitBounds = Self.searchResultBounds(of: photoBooths)
                // 고른 범위 전체가 곧 목록이므로 탭과 브랜드 필터 없이 결과 목록만 노출합니다.
                state.photoBoothListState.isSearchResultPresented = true
                // 검색을 끝내고 목록으로 돌아왔을 때 이 지역 탭에서 시작하도록 되돌립니다.
                state.photoBoothListState.selectedTab = .nearby
                // 이 목록에 없는 브랜드는 눌러도 빈 화면이 되므로 칩을 목록에 있는 브랜드로 좁힙니다.
                // 다만 현재 UI에는 검색 결과에 필터가 없어 이 값이 화면에 닿지 않습니다.
                // 자세한 내용과 남은 작업은 `PhotoBoothListFeature.State.filterBrands` 주석 참고.
                state.photoBoothListState.searchResultBrandFilters = result.brandFilters

                // 영역 조회를 대신하는 경로이므로 진행 중인 스트림 결과가 덮어쓰지 않도록 세대를 무효화합니다.
                state.photoBoothFetchContext.invalidate()
                state.photoBooths = IdentifiedArray(uniqueElements: photoBooths)
                state.visiblePhotoBooths = []
                state.photoBoothListState.visibleBooths = []
                state.isExploreHereButtonVisible = false
                return .merge(
                    .cancel(id: CancelID.mapFetch),
                    .cancel(id: CancelID.mapChunkProcessing),
                    .send(.photoBoothSearchAction(.dismissSearch)),
                    .concatenate(
                        // 좁혀진 칩에 없는 브랜드가 선택된 채로 남으면 목록이 통째로 비므로 함께 풉니다.
                        // 계산이 선택된 브랜드를 읽으므로 필터를 먼저 푼 뒤에 계산을 시작합니다.
                        .send(.photoBoothListAction(.clearFilterOptions)),
                        .send(.startBackgroundCalculation)
                    )
                )

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
            state.photoBoothListState.visibleBooths[id: id] ??
            state.photoBoothListState.favoriteBooths[id: id] ??
            state.photoBoothListState.visibleFavoriteBooths[id: id]
    }

    func currentFavoriteState(for id: PhotoBooth.ID, state: State) -> Bool? {
        if let pendingFavoriteState = state.pendingFavoriteUpdates[id] { return pendingFavoriteState }
        if state.selectedBooth?.id == id { return state.selectedBooth?.isFavorite }
        if let visiblePhotoBooth = state.visiblePhotoBooths[id: id] { return visiblePhotoBooth.isFavorite }
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

    /// 검색 결과를 한 화면에 담는 지도 영역입니다.
    ///
    /// 서버가 보여 줄 영역을 내려주지 않으므로 받은 부스 목록을 모두 감싸는 영역으로 직접 정합니다.
    /// 중심만 옮기면 넓은 지역을 골랐을 때 결과가 화면 밖으로 밀리므로 영역째 넘겨 배율까지 맞춥니다.
    /// 부스가 0건이면 옮길 이유가 없으므로 `nil`입니다.
    static func searchResultBounds(of photoBooths: [PhotoBooth]) -> GeographicBoundingBox? {
        guard let first = photoBooths.first?.coordinate else { return nil }
        var minLatitude = first.latitude, maxLatitude = first.latitude
        var minLongitude = first.longitude, maxLongitude = first.longitude
        for photoBooth in photoBooths.dropFirst() {
            let coordinate = photoBooth.coordinate
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }
        return .init(
            minLatitude: minLatitude,
            minLongitude: minLongitude,
            maxLatitude: maxLatitude,
            maxLongitude: maxLongitude
        )
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

    /// 지도에 반영 중인 검색을 지우고 검색 이전의 목록 구성으로 되돌립니다.
    func clearAppliedSearch(_ state: inout State) {
        state.appliedSearchQuery = nil
        state.photoBoothListState.isSearchResultPresented = false
        state.photoBoothListState.searchResultBrandFilters = nil
    }

    func resetToMapMode(_ state: inout State, for stage: SheetStage) {
        state.selectedBooth = nil
        state.detent = stage.detent
        state.cameraPosition = nil
        state.cameraFitBounds = nil
    }

    func selectPhotoBooth(_ state: inout State, photoBooth: PhotoBooth) {
        state.selectedBooth = photoBooth
        state.detent = SheetStage.photoBoothSelected.detent
        state.cameraFitBounds = nil
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
        state.cameraFitBounds = nil
        state.cameraPosition = .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    func checkIfRegionChanged(from lastLocation: CLLocation?, to currentLocation: CLLocation) -> Bool {
        guard let lastLocation else { return false }
        return currentLocation.distance(from: lastLocation) >= Constants.regionChangeDistanceThreshold
    }
    
    func initialExplorationTargetCoordinate(for state: State) -> GeographicCoordinate? {
        switch state.initialExplorationState {
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
    
}
