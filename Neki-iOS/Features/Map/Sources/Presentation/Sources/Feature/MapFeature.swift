//
//  MapFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/7/26.
//

import UIKit
import ComposableArchitecture
import CoreLocation

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
        var isSDKAuthSuccessful: Bool = false
        var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
        var userLocation: CLLocation?
        var isUserTrackingMode: Bool = false
        var cameraPosition: GeographicCoordinate?
        var currentBounds: GeographicBoundingBox?
        
        var detent: NekiSheetDetent = SheetStage.first.detent
        var selectedBooth: PhotoBooth?
        var photoBooths: IdentifiedArrayOf<PhotoBooth> = []
        var visiblePhotoBooths: IdentifiedArrayOf<PhotoBooth> = []
        var directionSheetPhotoBooth: PhotoBooth?
        
        var locationAuthorizationNeeded: Bool = true
        var isLocationAuthorized: Bool { locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse }
        
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
        
        // Internal Actions
        case updateLocationAuthorization(CLAuthorizationStatus)
        case updateSDKAuthStatus(Bool)
        case updateUserLocation(Result<CLLocation, Error>)
        case setUserTrackingMode(Bool)
        case didDetectMapInteraction
        case fetchPhotoBoothInBounds(Result<[PhotoBooth], Error>)
        case cameraMotionStarted
        case cameraMotionEnded(GeographicBoundingBox)
        
        // Binding Action
        case binding(BindingAction<State>)
        
        // Child Actions
        case photoBoothListAction(PhotoBoothListFeature.Action)
    }
    
    private enum CancelID {
        case photoBoothFetch
        case locationAuthorizationStream
        case sdkAuthorizationStream
        case locationStream
    }
    
    @Dependency(\.mapClient) private var mapClient
    @Dependency(\.photoBoothClient) private var photoBoothClient
    @Dependency(\.openURL) private var openURL
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.photoBoothListState, action: \.photoBoothListAction) { PhotoBoothListFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear:
                return .merge(
                    .run { send in
                        for await status in await mapClient.locationAuthorizationStatus() {
                            await send(.updateLocationAuthorization(status))
                        }
                    }
                        .cancellable(id: CancelID.locationAuthorizationStream, cancelInFlight: true),
                    .run { send in
                        for await isAuthorized in await mapClient.checkSDKAuthorizationStatus() {
                            await send(.updateSDKAuthStatus(isAuthorized))
                        }
                    }
                        .cancellable(id: CancelID.sdkAuthorizationStream, cancelInFlight: true),
                    .run { send in
                        for await location in await mapClient.trackingLocation() {
                            await send(.updateUserLocation(.success(location)))
                        }
                    }
                        .cancellable(id: CancelID.locationStream, cancelInFlight: true)
                )
                
            case .onDisappear:
                return .merge(
                    .cancel(id: CancelID.locationAuthorizationStream),
                    .cancel(id: CancelID.sdkAuthorizationStream),
                    .cancel(id: CancelID.locationStream),
                    .cancel(id: CancelID.photoBoothFetch)
                )
                
            case .requestPermission:
                state.locationAuthorizationNeeded = true
                return .run { _ in await mapClient.requestLocationAuthorization() }
                
            case .openAppSettings:
                // TODO: 설정 앱 동작 전에 안내문구 따위를 보여주도록 해야하는데 디자인 가이드가 없습니다.
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }
                
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
                
            case .didTapCurrentLocationButton:
                switch state.locationAuthorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse:
                    // TODO: 현위치 돌아가기 버튼 누르면 Stage 수준 몇으로 돌아가는지 확인 필요
                    return .run { send in
                        await send(.setUserTrackingMode(true))
                        
                        do {
                            let location = try await mapClient.getCurrentLocation()
                            await send(.updateUserLocation(.success(location)))
                        } catch {
                            await send(.setUserTrackingMode(false))
                            await send(.updateUserLocation(.failure(error)))
                        }
                    }
                    
                case .notDetermined:
                    state.isUserTrackingMode = false
                    return .send(.requestPermission)
                    
                case .denied, .restricted:
                    state.isUserTrackingMode = false
                    return .send(.openAppSettings)
                    
                @unknown default:
                    state.isUserTrackingMode = false
                    return .none
                }
                
            case .didTapDirectionAppsButton:
                state.directionSheetPhotoBooth = state.selectedBooth
                return .none
                
            case .updateLocationAuthorization(let status):
                state.locationAuthorizationStatus = status
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    guard state.userLocation == nil else { return .none }
                    return .send(.didTapCurrentLocationButton)
                    
                case .notDetermined:
                    guard state.locationAuthorizationNeeded == true else { return .none }
                    return .send(.requestPermission)
                    
                default:
                    return .none
                }
                
            case .updateSDKAuthStatus(let isAuthorized):
                state.isSDKAuthSuccessful = isAuthorized
                return .none
                
            case let .updateUserLocation(result):
                switch result {
                case let .success(location):
                    state.userLocation = location
                    
                    guard state.isUserTrackingMode else { return .none }
                    updateCameraPosition(&state, to: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
                    return .none
                    
                case let .failure(error):
                    // TODO: 에러 핸들링 로직이나 로그 찍기
                    print(error.localizedDescription)
                    return .none
                }
                
            case let .setUserTrackingMode(isUserTrackingMode):
                state.isUserTrackingMode = isUserTrackingMode
                return .none
                
            case .didDetectMapInteraction:
                state.isUserTrackingMode = false
                return .none
                
            case let .fetchPhotoBoothInBounds(.success(photoBooths)):
                let photoBooths = IdentifiedArray(uniqueElements: photoBooths)
                state.photoBooths = photoBooths
                handleFilterOptionChanged(&state)
                return .none
                
            case let .fetchPhotoBoothInBounds(.failure(error)):
                // TODO: 에러 핸들링 로직이나 로그를 찍는다던지 그런 작업은 이곳에 작성
                print(error.localizedDescription)
                return .none
                
            case .cameraMotionStarted:
                return .cancel(id: CancelID.photoBoothFetch)
                
            case let .cameraMotionEnded(bounds):
                state.currentBounds = bounds
                return .run { send in
                    await send(.fetchPhotoBoothInBounds(
                        Result {
                            try await photoBoothClient.fetchPhotoBooths(bounds: bounds)
                        }
                    ))
                }
                .debounce(id: CancelID.photoBoothFetch, for: 0.3, scheduler: DispatchQueue.main)
                .cancellable(id: CancelID.photoBoothFetch, cancelInFlight: true)
                
            case let .photoBoothListAction(.selectFilterOption(brand)):
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
}
