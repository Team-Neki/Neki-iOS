//
//  MapFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/7/26.
//

import Foundation
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
        var isSDKAuthSuccessful: Bool = true
        var isLocationAuthorized: Bool = false
        var userLocation: CLLocation?
        var cameraPosition: GeographicCoordinate?
        var currentBounds: GeographicBoundingBox?
        
        var detent: NekiSheetDetent = SheetStage.first.detent
        var selectedBooth: PhotoBooth?
        var photoBooths: IdentifiedArrayOf<PhotoBooth> = []
        var visiblePhotoBooths: IdentifiedArrayOf<PhotoBooth> = []
        
        var isDirectionOnCenter: Bool {
            guard let coordinate = userLocation?.coordinate, let cameraPosition = cameraPosition else { return false }
            return cameraPosition == GeographicCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        
        var photoBoothListState = PhotoBoothListFeature.State()
    }
    
    public enum Action: BindableAction {
        // View Actions
        case onAppear
        case requestPermission
        case openAppSettings
        case didTapGoBackToMapButton
        case didTapBooth(PhotoBooth)
        case didTapCloseDetail
        case didTapCurrentLocationButton
        
        // Internal Actions
        case updateLocationAuthorization(CLAuthorizationStatus)
        case updateSDKAuthStatus(Bool)
        case updateUserLocation(CLLocation)
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
        case tapMarker
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
                    },
                    .run { send in
                        for await isAuthorized in await mapClient.checkSDKAuthorizationStatus() {
                            await send(.updateSDKAuthStatus(isAuthorized))
                        }
                    },
                    .run { _ in await mapClient.requestLocationAuthorization() },
                    .run { send in
                        for await currentLocation in await mapClient.userLocation() {
                            await send(.updateUserLocation(currentLocation))
                        }
                    }
                )
                
            case .requestPermission:
                return .run { _ in await mapClient.requestLocationAuthorization() }
                
            case .openAppSettings:
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }
                
            case .didTapGoBackToMapButton:
                resetToMapMode(&state, for: .first)
                return .none
                
            case .didTapBooth(let photoBooth):
                selectPhotoBooth(&state, photoBooth: photoBooth)
                return .none
                
            case .didTapCloseDetail:
                resetToMapMode(&state, for: .second)
                return .none
                
            case .didTapCurrentLocationButton:
                // TODO: 현위치 돌아가기 버튼 누르면 Stage 수준 몇으로 돌아가는지 확인 필요
                guard let location = state.userLocation else { return .send(.requestPermission) }
                state.cameraPosition = .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                return .none
                
            case .updateLocationAuthorization(let status):
                return updateLocationAuthorization(&state, status: status)
                
            case .updateSDKAuthStatus(let isAuthorized):
                state.isSDKAuthSuccessful = isAuthorized
                return .none
                
            case let .updateUserLocation(currentLocation):
                state.userLocation = currentLocation
                return .none
                
            case let .fetchPhotoBoothInBounds(.success(photoBooths)):
                let photoBooths = IdentifiedArray(uniqueElements: photoBooths)
                state.photoBooths = photoBooths
                state.visiblePhotoBooths = photoBooths
                state.photoBoothListState.photoBooths = photoBooths
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
    func updateLocationAuthorization(_ state: inout State, status: CLAuthorizationStatus) -> Effect<Action> {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            state.isLocationAuthorized = true
            return .none
            
        case .notDetermined:
            state.isLocationAuthorized = false
            return .send(.requestPermission)
            
        default:
            state.isLocationAuthorized = false
            return .none
        }
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
    
    func handleFilterOptionChanged(_ state: inout State) {
        let activeFilters = state.photoBoothListState.filteredBrands
        if activeFilters.isEmpty {
            state.visiblePhotoBooths = state.photoBooths
        } else {
            state.visiblePhotoBooths = state.photoBooths.filter { activeFilters.contains($0.brand) }
        }
        
        state.photoBoothListState.photoBooths = state.visiblePhotoBooths
    }
}
