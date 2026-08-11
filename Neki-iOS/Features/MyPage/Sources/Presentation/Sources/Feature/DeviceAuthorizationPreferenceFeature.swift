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
import UserNotifications

@Reducer
struct DeviceAuthorizationPreferenceFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut

        var cameraAuthorizationStatus: AVAuthorizationStatus = .notDetermined
        var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
        var photosAuthorizationStatus: PHAuthorizationStatus = .notDetermined
        var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
        var isMarketingNotificationEnabled: Bool = false
        var confirmedMarketingNotificationEnabled: Bool = false
        var isUpdatingMarketingNotification: Bool = false
        var marketingNotificationUpdateRequestID: UUID?
        var isMarketingNotificationUpdateRequestInFlight: Bool = false
        
        var isCameraAuthorized: Bool { cameraAuthorizationStatus == .authorized }
        var isLocationAuthorized: Bool { locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse }
        var isPhotosAuthorized: Bool { photosAuthorizationStatus == .authorized || photosAuthorizationStatus == .limited }
        var isNotificationAuthorized: Bool {
            switch notificationAuthorizationStatus {
            case .authorized, .provisional, .ephemeral: true
            case .notDetermined, .denied: false
            @unknown default: false
            }
        }
    }
    
    enum Action: BindableAction {
        // View Actions
        case onAppear
        case dismissButtonTapped
        case cameraCellTapped
        case locationCellTapped
        case photosCellTapped
        case notificationsCellTapped
        
        // Internal Actions
        case updateCameraStatus(AVAuthorizationStatus)
        case updateLocationStatus(CLAuthorizationStatus)
        case updatePhotosStatus(PHAuthorizationStatus)
        case updateNotificationStatus(UNAuthorizationStatus)
        case commitMarketingNotificationUpdate(Bool, UUID)
        case marketingNotificationUpdateResponse(Bool, UUID, Result<Void, Error>)
        case pushNotificationSynchronizationResponse(Result<UNAuthorizationStatus, Error>)
        case openAppSettings

        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
        
        // Binding Actions
        case binding(BindingAction<State>)
    }

    private enum CancelID: Hashable {
        case marketingNotificationUpdateDebounce
        case marketingNotificationUpdateRequest
    }
    
    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.qrScannerClient) private var qrScannerClient
    @Dependency(\.mapClient) private var mapClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    @Dependency(\.authClient) private var authClient
    @Dependency(\.openURL) private var openURL
    @Dependency(\.date.now) private var now
    @Dependency(\.continuousClock) private var clock
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear:
                if case let .signedIn(user) = state.userSessionStatus {
                    state.isMarketingNotificationEnabled = user.marketingTermAgreed
                    state.confirmedMarketingNotificationEnabled = user.marketingTermAgreed
                }
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
                    },
                    .run { send in
                        let status = try await pushNotificationClient.checkAuthorizationStatus()
                        await send(.updateNotificationStatus(status))
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
                    return .send(.openAppSettings)
                    
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
                    return .send(.openAppSettings)
                    
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
                    return .send(.openAppSettings)
                    
                case .authorized, .limited:
                    return .send(.openAppSettings)
                    
                @unknown default:
                    return .none
                }

            case .notificationsCellTapped:
                switch state.notificationAuthorizationStatus {
                case .notDetermined:
                    return .run { send in
                        _ = try await pushNotificationClient.requestAuthorization()
                        await send(.pushNotificationSynchronizationResponse(
                            Result { try await pushNotificationClient.synchronizeDeviceToken() }
                        ))
                    }

                case .denied:
                    return .send(.openAppSettings)

                case .authorized, .provisional, .ephemeral:
                    return .send(.openAppSettings)

                @unknown default:
                    return .none
                }

            case .binding(\.isMarketingNotificationEnabled):
                state.isUpdatingMarketingNotification = true
                let requestedValue = state.isMarketingNotificationEnabled
                let requestID = UUID()
                state.marketingNotificationUpdateRequestID = requestID
                return .merge(
                    .cancel(id: CancelID.marketingNotificationUpdateRequest),
                    .run { send in
                        try await clock.sleep(for: .milliseconds(500))
                        await send(.commitMarketingNotificationUpdate(requestedValue, requestID))
                    }
                    .cancellable(id: CancelID.marketingNotificationUpdateDebounce, cancelInFlight: true)
                )

            case let .commitMarketingNotificationUpdate(requestedValue, requestID):
                guard requestID == state.marketingNotificationUpdateRequestID else { return .none }
                guard requestedValue != state.confirmedMarketingNotificationEnabled
                        || state.isMarketingNotificationUpdateRequestInFlight else {
                    state.isUpdatingMarketingNotification = false
                    state.marketingNotificationUpdateRequestID = nil
                    return .none
                }
                state.isMarketingNotificationUpdateRequestInFlight = true
                return .run { send in
                    await send(.marketingNotificationUpdateResponse(
                        requestedValue,
                        requestID,
                        Result { try await authClient.updateMarketingConsent(requestedValue) }
                    ))
                }
                .cancellable(id: CancelID.marketingNotificationUpdateRequest, cancelInFlight: true)

            case let .marketingNotificationUpdateResponse(requestedValue, requestID, .success):
                guard requestID == state.marketingNotificationUpdateRequestID else { return .none }
                state.isUpdatingMarketingNotification = false
                state.marketingNotificationUpdateRequestID = nil
                state.isMarketingNotificationUpdateRequestInFlight = false
                state.isMarketingNotificationEnabled = requestedValue
                state.confirmedMarketingNotificationEnabled = requestedValue
                state.$userSessionStatus.withLock {
                    guard case let .signedIn(currentUser) = $0 else { return }
                    var user = currentUser
                    user.marketingTermAgreed = requestedValue
                    $0 = .signedIn(user)
                }
                if case let .signedIn(user) = state.userSessionStatus {
                    let key = AppStorageKey.marketingConsentAlertPresentationCount(userID: user.id)
                    UserDefaults.standard.set(2, forKey: key)
                    UserDefaults.standard.set(
                        now,
                        forKey: AppStorageKey.marketingConsentLastManagedAt(userID: user.id)
                    )
                    UserDefaults.standard.set(
                        requestedValue
                            ? MarketingConsentManagementStatus.approved.rawValue
                            : MarketingConsentManagementStatus.rejected.rawValue,
                        forKey: AppStorageKey.marketingConsentManagementStatus(userID: user.id)
                    )
                }
                let message = requestedValue
                    ? "마케팅 알림 수신에 동의했어요."
                    : "마케팅 알림 수신을 거부했어요.\n마이페이지에서 언제든지 변경할 수 있어요."
                return .send(.delegate(.showToast(
                    NekiToastItem(message, style: .success)
                )))

            case let .marketingNotificationUpdateResponse(_, requestID, .failure(error)):
                guard requestID == state.marketingNotificationUpdateRequestID else { return .none }
                if error is CancellationError { return .none }
                state.isUpdatingMarketingNotification = false
                state.marketingNotificationUpdateRequestID = nil
                state.isMarketingNotificationUpdateRequestInFlight = false
                state.isMarketingNotificationEnabled = state.confirmedMarketingNotificationEnabled
                return .none

            case let .pushNotificationSynchronizationResponse(.success(status)):
                state.notificationAuthorizationStatus = status
                return .none

            case .pushNotificationSynchronizationResponse(.failure):
                return .run { send in
                    let status = try await pushNotificationClient.checkAuthorizationStatus()
                    await send(.updateNotificationStatus(status))
                }
                
            case .openAppSettings:
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }
                
            case let .updateCameraStatus(status):
                state.cameraAuthorizationStatus = status
                return .none
                
            case let .updatePhotosStatus(status):
                state.photosAuthorizationStatus = status
                return .none
                
            case let .updateLocationStatus(status):
                state.locationAuthorizationStatus = status
                return .none

            case let .updateNotificationStatus(status):
                state.notificationAuthorizationStatus = status
                return .none
                
            default:
                return .none
            }
        }
    }
}
