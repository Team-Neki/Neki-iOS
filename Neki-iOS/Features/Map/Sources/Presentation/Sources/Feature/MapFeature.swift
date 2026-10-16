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
        /// 검색 결과가 0곳일 때의 높이입니다.
        ///
        /// 결과 없음 시안(375×812)에서 시트 위쪽이 369pt에 오도록 맞춘 비율입니다.
        /// 결과가 없다는 안내가 탭바에 가리지 않도록 ``second``보다 높게 둡니다.
        case emptySearchResult
        
        var detent: NekiSheetDetent {
            switch self {
            case .first: return .fraction(0.134)
            case .second: return .fraction(0.305)
            case .third: return .large
            case .photoBoothSelected: return .hidden
            case .emptySearchResult: return .fraction(0.532)
            }
        }

        /// 시트를 끌어 맞출 수 있는 높이입니다.
        ///
        /// 시트는 지금 높이를 이 목록에서 가장 가까운 높이로 그리므로, 검색 결과가 0곳인 동안에는 ``second`` 대신 ``emptySearchResult``를 넣습니다.
        static func detents(isSearchResultEmpty: Bool) -> Set<NekiSheetDetent> {
            Set([Self.third, isSearchResultEmpty ? .emptySearchResult : .second, .first, .photoBoothSelected].map(\.detent))
        }
    }

    /// 카메라를 한 지점으로 옮겨 달라는 요청입니다.
    ///
    /// 부스를 고르거나 현재 위치로 돌아갈 때처럼 한 지점을 화면 가운데에 두어야 하는 경우에 씁니다.
    /// 영역에 맞추는 ``CameraFitRequest``와 동시에 채우지 않습니다.
    ///
    /// 좌표만으로는 같은 지점으로 다시 옮겨 달라는 요청을 구분할 수 없어 세대를 함께 둡니다.
    /// 지도를 옮긴 뒤 같은 부스를 다시 골라도 새 세대라 카메라가 다시 옮겨집니다.
    /// 카메라가 멈춘 위치는 ``State/currentBounds``로만 받고 이 요청에 되돌려 쓰지 않습니다.
    /// 되돌려 쓰면 지도가 그 값을 새 요청으로 보고, 진행 중인 이동을 멈춘 자리로 되돌립니다.
    struct CameraMoveRequest: Equatable {
        private(set) var generation: UInt = .zero
        private(set) var coordinate: GeographicCoordinate?

        /// 새 지점 이동을 요청합니다.
        mutating func move(to coordinate: GeographicCoordinate) {
            generation &+= 1
            self.coordinate = coordinate
        }

        /// 옮길 지점이 없음을 표시합니다.
        mutating func clear() {
            coordinate = nil
        }
    }

    /// 카메라를 한 지점이 아니라 특정 영역에 맞춰 달라는 요청입니다.
    ///
    /// 검색 결과처럼 여러 지점을 한 화면에 담아야 하는 경우에 씁니다.
    /// 한 지점으로 옮기는 ``CameraMoveRequest``와 동시에 채우지 않습니다.
    ///
    /// 좌표만으로는 서로 다른 두 요청을 구분할 수 없어 세대를 함께 둡니다.
    /// 검색 뒤 지도를 옮기고 같은 검색을 다시 해도 새 세대라 카메라가 다시 맞춰집니다.
    struct CameraFitRequest: Equatable {
        private(set) var generation: UInt = .zero
        private(set) var bounds: GeographicBoundingBox?

        /// 새 영역 맞춤을 요청합니다.
        mutating func fit(to bounds: GeographicBoundingBox) {
            generation &+= 1
            self.bounds = bounds
        }

        /// 맞출 영역이 없음을 표시합니다.
        mutating func clear() {
            bounds = nil
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
        /// 시트를 끌어 맞출 수 있는 높이입니다. 검색 결과가 0곳인 동안에는 결과 없음 높이로 맞춥니다.
        var sheetDetents: Set<NekiSheetDetent> { SheetStage.detents(isSearchResultEmpty: isSearchResultEmpty) }
        var isExploreHereButtonVisible: Bool = false
        var isSearchPresented: Bool = false
        /// 지도에 반영 중인 검색어입니다. 검색 결과를 보고 있지 않으면 `nil`입니다.
        ///
        /// 상단 검색 필드를 검색 완료 형태로 유지하고, 검색 화면으로 되돌아갈 때 그대로 다시 검색합니다.
        var appliedSearchQuery: PhotoBoothSearchQuery?
        /// 지도에 반영 중인 검색이 부스 하나를 바로 선택한 검색인지 여부입니다.
        ///
        /// 이 검색은 결과 시트 없이 부스 상세만 띄우므로, 상세를 닫으면 그 부스를 고른 검색 화면으로 돌아갑니다.
        /// 지역·역 검색이나 한 지점으로 좁혀지지 않은 부스 검색은 결과 시트로 돌아가므로 `false`입니다.
        var isSinglePhotoBoothSearchApplied: Bool = false
        /// 지도에 반영한 검색 결과가 0곳인지 여부입니다. 결과를 조회하는 중이거나 조회에 실패했으면 `false`입니다.
        var isSearchResultEmpty: Bool {
            appliedSearchQuery != nil
                && photoBoothListState.isSearchResultPresented
                && photoBoothListState.searchResultPhase == .loaded
                && photoBooths.isEmpty
        }
        var isPermissionAlertPresented: Bool = false
        var initialExplorationState: MapInitialExplorationState = .awaitingPermission
        
        // Map State
        var cameraMoveRequest = CameraMoveRequest()
        var cameraFitRequest = CameraFitRequest()
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
        /// 고른 검색 후보로 부스 목록을 조회한 차수입니다.
        ///
        /// 결과가 오기 전에 다른 후보를 고르거나 검색을 끝내면 차수가 바뀌어, 늦게 온 응답이 지금 화면을 덮지 않습니다.
        var searchResultFetchGeneration: UInt = .zero
        
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
        /// 다른 탭에서 지도 탭으로 돌아왔음을 알립니다. 탭 전환을 아는 상위 화면(메인 탭)이 보냅니다.
        case didEnterTab
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
        
        // Search
        case searchResultResponse(Result<PhotoBoothSearchResult, PhotoBoothSearchFailure>, candidate: PhotoBoothSearchCandidate, generation: UInt)
        
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
            favoriteList: IdentifiedArrayOf<PhotoBooth>,
            distances: [GeographicCoordinate: GeographicDistance],
            sortCoordinate: GeographicCoordinate?,
            sortOrder: PhotoBoothListFeature.FavoriteSortOrder
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
        case searchResult
    }
    
    @Dependency(\.mapClient) private var mapClient
    @Dependency(\.photoBoothClient) private var photoBoothClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.distanceFormatterClient) private var distanceFormatter
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
                
            case .didEnterTab:
                // 다른 탭에서 돌아오면 검색 여부와 관계없이 첫 지도 화면을 보여 줍니다.
                // 카메라 이동과 지역 조회는 새로 그려진 지도가 위치 권한을 다시 받아 처리하므로, 여기서는 화면 상태만 되돌립니다.
                if state.appliedSearchQuery != nil {
                    // 검색 결과를 보고 있었다면 검색 종료(X)와 같이 검색을 지우고 시트 높이와 탭·필터를 첫 진입 값으로 되돌립니다.
                    clearAppliedSearch(&state)
                    resetTabAndFilters(&state)
                    resetToMapMode(&state, for: .first)
                } else if state.isLocationAuthorized {
                    // 검색 중이 아니면 목록 탭·필터·하트는 그대로 둡니다.
                    // 위치 권한이 없으면 카메라만 기본 위치로 옮기므로 상세와 시트 높이도 그대로 둡니다.
                    resetToMapMode(&state, for: .first)
                }
                // 결과를 조회하던 중이었다면 그 조회를 멈추고, 검색 화면을 띄운 채로 탭이 바뀌었다면 그 화면도 닫습니다.
                return .merge(
                    .cancel(id: CancelID.searchResult),
                    state.isSearchPresented ? .send(.photoBoothSearchAction(.dismissSearch)) : .none
                )
                
                // MARK: - Permission Flow
            case .requestPermission:
                state.locationAuthorizationNeeded = true
                return .run { _ in await mapClient.requestLocationAuthorization() }
                
            case .updateLocationAuthorization(let status):
                state.locationAuthorizationStatus = status
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    state.initialExplorationState = .waitingForUserLocation
                    // 위치 권한을 받으면 현위치 버튼을 누른 것과 같이 지도 모드로 돌아와 현위치를 따라갑니다.
                    returnToMapModeUnlessSearching(&state)
                    followUserLocation(&state)
                    return .run { send in
                        for await location in await mapClient.trackingLocation() {
                            await send(.updateUserLocation(.success(location)))
                        }
                    }.cancellable(id: CancelID.locationStream, cancelInFlight: true)
                    
                case .notDetermined:
                    state.initialExplorationState = .awaitingPermission
                    return state.locationAuthorizationNeeded ? .send(.requestPermission) : .none
                    
                case .denied, .restricted:
                    state.isUserTrackingMode = false
                    state.initialExplorationState = .readyForDefaultLocation
                    updateCameraPosition(&state, to: Constants.defaultInitialPosition.coordinate)
                    // 위치에 동의하지 않으면 다음 검색부터 기본 좌표를 거리 기준으로 씁니다.
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
                return .merge(
                    .send(.attemptInitialExploration),
                    .send(.startBackgroundCalculation)
                )
                
            case .didTapCurrentLocationButton:
                returnToMapModeUnlessSearching(&state)
                switch state.locationAuthorizationStatus {
                case .notDetermined:
                    return .send(.requestPermission)
                case .restricted, .denied:
                    return .send(.presentPermissionAlert)
                case .authorizedAlways, .authorizedWhenInUse, .authorized:
                    followUserLocation(&state)
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
                return .merge(
                    .send(.attemptInitialExploration),
                    .send(.startBackgroundCalculation)
                )
                
            case let .updateExploreButtonVisibility(isVisible):
                // 검색 결과를 보는 동안 영역을 다시 조회하면 검색 결과가 지워지므로 재탐색 버튼을 띄우지 않습니다.
                state.isExploreHereButtonVisible = isVisible && state.appliedSearchQuery == nil
                return .none
                
            case .didTapSearchField:
                return presentSearch(&state)

            case .didTapClearSearchButton:
                return endSearch(&state)

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
                        .cancel(id: CancelID.calculation),
                        .cancel(id: CancelID.searchResult)
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
                updateFavoriteSortCoordinate(&state.photoBoothListState, coordinate: state.isLocationAuthorized ? state.userGeographicCoordinate : nil)
                let favoriteBooths = mergedFavoriteBooths(from: photoBooths, state: state)
                let favoriteBoothCount = favoriteBooths.count
                let viewEventEffect: Effect<Action> = shouldLogViewEvent
                    ? .run { _ in await analytics.logEvent(MapAnalyticsEvent.favoriteBoothView(favoriteBoothCount: favoriteBoothCount)) }
                    : .none
                return .concatenate(
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
                let sortOrder = state.photoBoothListState.favoriteSortOrder
                let sortCoordinate = state.photoBoothListState.favoriteSortCoordinate
                let cachedDistances = state.photoBoothListState.favoriteDistances
                return .run { send in
                    var distances = cachedDistances
                    if distances.isEmpty == false {
                        let retainedCoordinates = Set(favoriteBooths.map(\.coordinate))
                        if distances.keys.allSatisfy({ retainedCoordinates.contains($0) }) == false {
                            distances = distances.filter { retainedCoordinates.contains($0.key) }
                        }
                    }
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
                    let filteredFavorites = Self.visibleFavoritePhotoBooths(favoriteBooths, activeBrandIDs: activeBrandIDs)
                    if sortOrder == .distance, let sortCoordinate {
                        // 비교할 때마다 거리를 계산하지 않고 지점당 한 번만 계산합니다.
                        let measuredBooths = filteredFavorites.enumerated().map { index, booth in
                            let distance: GeographicDistance
                            if let cachedDistance = distances[booth.coordinate] {
                                distance = cachedDistance
                            } else {
                                distance = distanceFormatter.distance(sortCoordinate, booth.coordinate)
                                distances[booth.coordinate] = distance
                            }
                            let meters = distance.meters.isFinite && distance.meters >= .zero ? distance.meters : .infinity
                            return (index: index, booth: booth, meters: meters)
                        }
                        visibleFavoriteBooths = IdentifiedArray(uniqueElements: measuredBooths.sorted {
                            $0.meters == $1.meters ? $0.index < $1.index : $0.meters < $1.meters
                        }.map(\.booth))
                    } else {
                        visibleFavoriteBooths = filteredFavorites
                    }
                    try Task.checkCancellation()
                    await send(.didFinishBackgroundCalculation(
                        map: visibleMapBooths,
                        list: visibleListBooths,
                        favoriteList: visibleFavoriteBooths,
                        distances: distances,
                        sortCoordinate: sortCoordinate,
                        sortOrder: sortOrder
                    ))
                }
                .cancellable(id: CancelID.calculation, cancelInFlight: true)
                
            case let .didFinishBackgroundCalculation(map, list, favoriteList, distances, sortCoordinate, sortOrder):
                guard state.photoBoothListState.favoriteSortCoordinate == sortCoordinate,
                      state.photoBoothListState.favoriteSortOrder == sortOrder else { return .none }
                state.visiblePhotoBooths = map
                state.photoBoothListState.favoriteDistances = distances
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
                // 부스 하나를 바로 고른 검색은 돌아갈 결과 시트가 없으므로, 상세를 닫으면 그 부스를 고른 검색 화면으로 돌아갑니다.
                // 검색은 끝내지 않으므로 다른 후보를 고르면 그 결과로 바로 바뀝니다.
                // 시트는 검색 화면에 가려지며, 후보를 고르지 않고 나가면 검색을 끝내면서 어차피 처음 높이가 됩니다.
                // 빈 지도를 눌러도 이 액션이 오므로, 닫을 상세가 있을 때만 검색 화면으로 돌아갑니다.
                if state.isSinglePhotoBoothSearchApplied, state.selectedBooth != nil {
                    resetToMapMode(&state, for: .first)
                    return presentSearch(&state)
                }
                // 결과가 0곳인 검색에서 빈 지도를 눌렀다면 결과 없음 높이를 그대로 둡니다.
                resetToMapMode(&state, for: state.isSearchResultEmpty ? .emptySearchResult : .second)
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

            case let .photoBoothListAction(.selectFavoriteSortOrder(order)):
                switch order {
                case .distance:
                    guard state.isLocationAuthorized, let coordinate = state.userGeographicCoordinate else {
                        return .send(.presentPermissionAlert)
                    }
                    guard state.photoBoothListState.favoriteSortOrder != order ||
                          state.photoBoothListState.favoriteSortCoordinate != coordinate else { return .none }
                    updateFavoriteSortCoordinate(&state.photoBoothListState, coordinate: coordinate)
                case .saved:
                    guard state.photoBoothListState.favoriteSortOrder != order else { return .none }
                }
                state.photoBoothListState.favoriteSortOrder = order
                return .send(.startBackgroundCalculation)

            case let .photoBoothListAction(.delegate(.didTapFavorite(photoBooth))):
                return .send(.didTapFavorite(photoBooth))

            case .photoBoothSearchAction(.dismissSearch):
                state.isSearchPresented = false
                // 부스 상세를 닫고 돌아온 검색 화면에서 다른 후보를 고르지 않고 나가면 지도에 남길 결과가 없으므로 검색을 끝냅니다.
                // 후보를 고른 직후에도 이 액션이 오지만, 그때는 부스가 선택돼 있거나 결과 시트 검색이라 해당하지 않습니다.
                guard state.isSinglePhotoBoothSearchApplied, state.selectedBooth == nil else { return .none }
                return endSearch(&state)

            case let .photoBoothSearchAction(.delegate(.didSelectCandidate(candidate, query, distanceOrigin))):
                // 후보를 고르면 검색 화면을 바로 닫고, 지도에서 부스 목록을 조회하는 동안 시트에 로딩을 띄웁니다.
                state.isSearchPresented = false
                state.isUserTrackingMode = false
                // 결과를 보는 동안 상단 검색 필드에 검색어를 검색 완료 형태로 남기고, 재탐색 버튼은 내립니다.
                state.appliedSearchQuery = query
                state.isExploreHereButtonVisible = false
                // 한 지점으로 좁혀지는지는 결과가 와야 알 수 있습니다.
                // 부스를 바로 고른 검색에서 다시 검색해 넘어와도 결과가 오기 전에는 결과 시트 검색으로 둡니다.
                state.isSinglePhotoBoothSearchApplied = false

                // 부스 후보는 대부분 한 지점이라 결과가 오면 상세를 띄우고 시트를 내리므로, 가장 낮은 높이에서 기다립니다.
                // 지역과 지하철역은 결과 시트를 보여 줄 높이에서 기다립니다.
                resetToMapMode(&state, for: candidate.type == .photoBooth ? .first : .second)
                state.photoBoothListState.isSearchResultPresented = true
                state.photoBoothListState.searchResultPhase = .loading
                state.photoBoothListState.searchResultBrandFilters = nil
                if candidate.type != .photoBooth {
                    // 지역·역 검색 결과에는 기존 탭과 필터를 섞지 않습니다.
                    // 좁혀진 칩에 없는 브랜드가 선택된 채로 남으면 목록이 통째로 비고,
                    // 즐겨찾기 마커 필터가 켜져 있으면 지도에서 검색 결과 마커가 가려집니다.
                    // 부스를 바로 고른 검색은 지도에 한 지점만 찍으므로 탭과 필터를 그대로 둡니다.
                    resetTabAndFilters(&state)
                }

                // 결과로 바뀔 기존 마커와 목록은 비웁니다. 남겨 두면 로딩 중에 눌러 연 상세가 결과와 함께 닫히는 꼬임이 생깁니다.
                // 이 조회가 영역 조회를 대신하므로, 진행 중인 영역 조회 결과가 덮어쓰지 않도록 세대를 무효화하고 취소합니다.
                state.photoBoothFetchContext.invalidate()
                state.photoBooths = []
                state.visiblePhotoBooths = []
                state.photoBoothListState.visibleBooths = []

                state.searchResultFetchGeneration &+= 1
                let generation = state.searchResultFetchGeneration
                let fetchEffect: Effect<Action> = .run { send in
                    do {
                        // 부스 목록과 필터는 요청 body가 같아 함께 조회하고, 둘 다 도착해야 지도를 다시 그립니다.
                        // 후보 목록과 거리가 어긋나지 않도록 검색 화면이 검색할 때 고정한 기준 좌표를 그대로 넘깁니다.
                        async let photoBooths = photoBoothClient.fetchSearchPhotoBooths(candidate, distanceOrigin)
                        async let brandFilters = photoBoothClient.fetchSearchBrandFilters(candidate)
                        let result = try await PhotoBoothSearchResult(photoBooths: photoBooths, brandFilters: brandFilters)
                        await send(.searchResultResponse(.success(result), candidate: candidate, generation: generation))
                    } catch is CancellationError { return } catch {
                        await send(.searchResultResponse(
                            .failure(PhotoBoothSearchFailure(from: error)),
                            candidate: candidate,
                            generation: generation
                        ))
                    }
                }
                .cancellable(id: CancelID.searchResult, cancelInFlight: true)

                return .merge(
                    .cancel(id: CancelID.mapFetch),
                    .cancel(id: CancelID.mapChunkProcessing),
                    // 넘겨받은 검색어와 기준 좌표만 남기고 검색 화면은 처음 상태로 비웁니다.
                    .send(.photoBoothSearchAction(.dismissSearch)),
                    .send(.startBackgroundCalculation),
                    fetchEffect
                )

            case let .searchResultResponse(.success(result), candidate, generation):
                guard state.searchResultFetchGeneration == generation else { return .none }
                return applySearchResult(&state, candidate: candidate, result: result)

            case let .searchResultResponse(.failure(failure), _, generation):
                guard state.searchResultFetchGeneration == generation else { return .none }
                // 실패해도 상단 검색 필드에 검색어가 남아 있어, 누르면 그 검색어로 검색 화면에 돌아가 다시 고를 수 있습니다.
                state.photoBoothListState.searchResultPhase = .failure(failure)
                // 부스 후보는 가장 낮은 높이에서 기다렸으므로, 실패 문구가 보이도록 결과 시트 높이로 올립니다.
                if state.detent == SheetStage.first.detent {
                    state.detent = SheetStage.second.detent
                }
                return .none

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
    ///
    /// 결과를 조회하던 중이었다면 늦게 온 응답을 반영하지 않도록 조회 차수를 넘깁니다. 진행 중인 조회의 취소는 부르는 쪽이 합니다.
    func clearAppliedSearch(_ state: inout State) {
        state.appliedSearchQuery = nil
        state.isSinglePhotoBoothSearchApplied = false
        state.searchResultFetchGeneration &+= 1
        state.photoBoothListState.isSearchResultPresented = false
        state.photoBoothListState.searchResultPhase = .loaded
        state.photoBoothListState.isSearchResultBrandFilterSheetPresented = false
        state.photoBoothListState.searchResultBrandFilters = nil
    }

    /// 목록 탭과 필터를 지도 탭에 처음 들어왔을 때의 값으로 되돌립니다.
    ///
    /// `이 지역 포토부스` 탭을 고르고, 브랜드 필터를 풀고, 즐겨찾기 마커 필터를 끕니다.
    func resetTabAndFilters(_ state: inout State) {
        state.photoBoothListState.selectedTab = .nearby
        state.photoBoothListState.filteredBrands = []
        state.isFavoriteMarkerFilterEnabled = false
    }

    /// 검색 화면을 띄웁니다.
    ///
    /// 지도에 반영 중인 검색이 있으면 그 검색어로 되돌려 후보 목록부터 다시 보여 줍니다.
    /// 화면이 뜨기 전에 검색어가 자리해야 검색 완료 형태로 열리므로 이펙트로 미루지 않습니다.
    func presentSearch(_ state: inout State) -> Effect<Action> {
        state.isSearchPresented = true
        guard let query = state.appliedSearchQuery else { return .none }
        state.photoBoothSearchState.searchText = query.rawValue
        return .send(.photoBoothSearchAction(.beginSearch(query)))
    }

    /// 검색을 끝내고 시트 높이와 탭·필터를 지도 탭에 처음 들어왔을 때의 값으로 되돌립니다.
    ///
    /// 카메라는 옮기지 않으므로 보고 있던 지역을 다시 조회해 이 지역 목록을 채웁니다.
    func endSearch(_ state: inout State) -> Effect<Action> {
        clearAppliedSearch(&state)
        resetTabAndFilters(&state)
        resetToMapMode(&state, for: .first)
        // 결과를 조회하던 중이었다면 그 조회도 멈춥니다. 보고 있던 지역을 다시 조회할 때는 영역 조회가 함께 멈춥니다.
        guard let bounds = state.currentBounds else { return .cancel(id: CancelID.searchResult) }
        return .send(.fetchPhotoBooths(bounds: bounds))
    }

    /// 고른 후보로 조회한 부스 목록을 지도와 시트에 반영합니다.
    ///
    /// 로딩 중에 현위치 버튼을 누르거나 지도를 옮겼어도, 사용자가 고른 결과이므로 결과에 맞춰 카메라를 옮깁니다.
    func applySearchResult(
        _ state: inout State,
        candidate: PhotoBoothSearchCandidate,
        result: PhotoBoothSearchResult
    ) -> Effect<Action> {
        state.isUserTrackingMode = false
        state.photoBoothListState.searchResultPhase = .loaded
        let photoBooths = result.photoBooths

        // 부스를 고르면 조회한 그 지점만 선택하고 결과 시트는 띄우지 않습니다.
        // 지도에 한 지점만 찍는 경로라 필터 칩도 그대로 둡니다.
        // 지도에서 숨긴 지점이라 결과가 없거나 한 지점으로 좁혀지지 않으면 지역·역처럼 결과 시트로 보여 줍니다.
        if candidate.type == .photoBooth, photoBooths.count == 1, let photoBooth = photoBooths.first {
            // 돌아갈 결과 시트가 없으므로 상세를 닫으면 이 검색 화면으로 돌아가도록 표시해 둡니다.
            state.isSinglePhotoBoothSearchApplied = true
            state.photoBoothListState.isSearchResultPresented = false
            selectPhotoBooth(&state, photoBooth: photoBooth)
            state.photoBooths = [photoBooth]
            return .send(.startBackgroundCalculation)
        }

        // 지역과 지하철역은 응답 자체가 지도에 그릴 목록이므로 영역 조회를 대신합니다.
        // 서버가 보여 줄 영역을 주지 않아 목록으로 직접 정하며, 0건이면 지도를 옮기지 않습니다.
        // 0건이면 결과가 없다는 안내가 다 보이도록 결과 없음 높이로 올립니다.
        resetToMapMode(&state, for: photoBooths.isEmpty ? .emptySearchResult : .second)
        if let bounds = Self.searchResultBounds(of: photoBooths) {
            state.cameraFitRequest.fit(to: bounds)
        }
        // 고른 범위 전체가 곧 목록이므로 탭 없이 개수, `브랜드` 칩, 결과 목록만 노출합니다.
        // 이 목록에 없는 브랜드는 눌러도 빈 화면이 되므로 브랜드 필터 시트의 칩을 목록에 있는 브랜드로 좁힙니다.
        state.photoBoothListState.searchResultBrandFilters = result.brandFilters
        // 한 지점으로 좁혀지지 않은 부스 검색도 결과 시트로 보여 주므로 기존 탭과 필터를 섞지 않습니다.
        resetTabAndFilters(&state)
        state.photoBooths = IdentifiedArray(uniqueElements: photoBooths)
        state.visiblePhotoBooths = []
        state.photoBoothListState.visibleBooths = []
        return .send(.startBackgroundCalculation)
    }

    func resetToMapMode(_ state: inout State, for stage: SheetStage) {
        state.selectedBooth = nil
        state.detent = stage.detent
        state.cameraMoveRequest.clear()
        state.cameraFitRequest.clear()
    }

    /// 검색 결과를 보고 있지 않으면 상세를 닫고 시트를 처음 높이로 내려 지도 모드로 되돌립니다.
    ///
    /// 검색 결과를 보는 동안에는 현위치로 옮겨도 검색 모드를 유지하므로, 시트와 상세를 그대로 두고 카메라만 옮깁니다.
    func returnToMapModeUnlessSearching(_ state: inout State) {
        guard state.appliedSearchQuery == nil else { return }
        resetToMapMode(&state, for: .first)
    }

    /// 위치 추적을 켜고, 받아 둔 현위치가 있으면 카메라를 그곳으로 옮깁니다.
    ///
    /// 현위치를 아직 받지 못했으면 추적이 켜져 있으므로 위치를 받을 때 옮깁니다.
    func followUserLocation(_ state: inout State) {
        state.isUserTrackingMode = true
        if let location = state.userLocation { updateCameraPosition(&state, to: location.coordinate) }
    }

    func selectPhotoBooth(_ state: inout State, photoBooth: PhotoBooth) {
        state.selectedBooth = photoBooth
        state.detent = SheetStage.photoBoothSelected.detent
        state.cameraFitRequest.clear()
        state.cameraMoveRequest.move(to: photoBooth.coordinate)
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

    func updateFavoriteSortCoordinate(_ state: inout PhotoBoothListFeature.State, coordinate: GeographicCoordinate?) {
        // 조회·정렬 시점에 좌표가 없으면 실제 목록 순서와 선택 표시를 함께 저장순으로 맞춥니다.
        guard let coordinate else {
            state.favoriteSortOrder = .saved
            state.favoriteSortCoordinate = nil
            state.favoriteDistances.removeAll()
            return
        }
        guard state.favoriteSortCoordinate != coordinate else { return }
        state.favoriteSortCoordinate = coordinate
        state.favoriteDistances.removeAll()
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
        state.cameraFitRequest.clear()
        state.cameraMoveRequest.move(to: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
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
