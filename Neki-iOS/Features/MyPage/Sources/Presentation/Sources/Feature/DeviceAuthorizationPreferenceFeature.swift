//
//  DeviceAuthorizationPreferenceFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/20/26.
//

import UIKit
import ComposableArchitecture
import AVFoundation
import CoreLocation
import Photos
// TODO: 알림 관련 임포팅 필요
// import Firebase

@Reducer
struct DeviceAuthorizationPreferenceFeature {
    @ObservableState
    struct State: Equatable {
        var cameraAuthorizationStatus: AVAuthorizationStatus = .notDetermined
        var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
        var photosAuthorizationStatus: PHAuthorizationStatus = .notDetermined
        
        var isCameraAuthorized: Bool { cameraAuthorizationStatus == .authorized }
        var isLocationAuthorized: Bool { locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse }
        var isPhotosAuthorized: Bool { photosAuthorizationStatus == .authorized || photosAuthorizationStatus == .limited }
        
        var isAlertPresented: Bool = false
        var alertItem: AlertItem?
    }
    
    enum Action: BindableAction {
        // View Actions
        case onAppear
        case dismissButtonTapped
        case cameraCellTapped
        case locationCellTapped
        case photosCellTapped
        
        // Internal Actions
        case updateCameraStatus(AVAuthorizationStatus)
        case updateLocationStatus(CLAuthorizationStatus)
        case updatePhotosStatus(PHAuthorizationStatus)
        case openAppSettings
        case alertDismissed
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    enum AlertItem {
        case notification, photos, location, camera
        
        var title: String {
            switch self {
            case .notification: return "알림 권한"
            case .photos: return "갤러리 권한"
            case .location: return "위치 권한"
            case .camera: return "카메라 권한"
            }
        }
        
        var description: String {
            switch self {
            case .notification: return "사진 저장 완료 오류 안내를 알려드리기 위해 알림 권한이 필요해요."
            case .photos: return "사진을 불러와 네키에 저장 및 관리하기 위해 갤러리 접근 권한이 필요해요."
            case .location: return "주변 포토부스를 찾기 위해 위치 사용 권한이 필요해요"
            case .camera: return "QR 인식을 위해 카메라 접근이 필요해요."
            }
        }
    }
    
    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.qrScannerClient) private var qrScannerClient
    @Dependency(\.mapClient) private var mapClient
    @Dependency(\.openURL) private var openURL
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear:
                return .merge(
                    .run { send in
                        let status = qrScannerClient.checkAuthorizationStatus()
                        await send(.updateCameraStatus(status))
                    },
                    .run { send in
                        for await status in await mapClient.locationAuthorizationStatus() {
                            await send(.updateLocationStatus(status))
                        }
                    },
                    .run { send in
                        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                        await send(.updatePhotosStatus(status))
                    }
                )
                
            case .dismissButtonTapped:
                return .run { _ in await dismiss() }
                
            case .cameraCellTapped:
                switch state.cameraAuthorizationStatus {
                case .notDetermined:
                    return .run { send in
                        _ = await qrScannerClient.requestAccess()
                        let newStatus = qrScannerClient.checkAuthorizationStatus()
                        await send(.updateCameraStatus(newStatus))
                    }
                    
                case .denied, .restricted:
                    state.alertItem = .camera
                    state.isAlertPresented = true
                    return .none
                    
                case .authorized:
                    return .send(.openAppSettings)
                    
                @unknown default:
                    return .none
                }
                
            case .locationCellTapped:
                switch state.locationAuthorizationStatus {
                case .notDetermined:
                    return .run { send in
                        await mapClient.requestLocationAuthorization()
                    }
                    
                case .denied, .restricted:
                    state.alertItem = .location
                    state.isAlertPresented = true
                    return .none
                    
                case .authorizedAlways, .authorizedWhenInUse:
                    return .send(.openAppSettings)
                    
                @unknown default:
                    return .none
                }
                
            case .photosCellTapped:
                switch state.photosAuthorizationStatus {
                case .notDetermined:
                    return .run { send in
                        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                        await send(.updatePhotosStatus(newStatus))
                    }
                    
                case .denied, .restricted:
                    state.alertItem = .photos
                    state.isAlertPresented = true
                    return .none
                    
                case .authorized, .limited:
                    return .send(.openAppSettings)
                    
                @unknown default:
                    return .none
                }
                
            case .openAppSettings:
                state.alertItem = nil
                state.isAlertPresented = false
                return .run { send in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }
                
            case .alertDismissed:
                state.alertItem = nil
                state.isAlertPresented = false
                return .none
                
            case let .updateCameraStatus(status):
                state.cameraAuthorizationStatus = status
                return.none
                
            case let .updatePhotosStatus(status):
                state.photosAuthorizationStatus = status
                return .none
                
            case let .updateLocationStatus(status):
                state.locationAuthorizationStatus = status
                return .none
                
            default:
                return .none
            }
        }
    }
}
