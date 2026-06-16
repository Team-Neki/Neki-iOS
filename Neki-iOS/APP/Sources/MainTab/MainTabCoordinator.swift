//
//  MainTabCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation
import UserNotifications
// import Pose
// import Archive

@Reducer
struct MainTabCoordinator {
    
    @ObservableState
    struct State {
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut
        var selectedTab: NekiTab = .archive
        
        // 하위 코디네이터들의 State를 보유
        var pose = PoseCoordinator.State()
        var archive = ArchiveCoordinator.State()
        var map = MapCoordinator.State()
        var myPage = MyPageCoordinator.State()
        
        var imagePicker = ImagePickerFeature.State(mediaType: .photoBooth, autoUpload: false)
        
        var isPhotoPickerPresented: Bool = false
        var pendingPresentation: PendingPresentation?
        var isLoading: Bool = false
        
        @Presents var destination: Destination.State?
        
        var isTabbarHidden: Bool = false
        var toast: NekiToastItem? = nil
        var isPermissionAlertPresented: Bool = false
        var shouldPresentMarketingConsentAlert: Bool
        var isMarketingConsentAlertPresented: Bool = false
        var isUpdatingMarketingConsent: Bool = false

        init(shouldPresentMarketingConsentAlert: Bool = false) {
            self.shouldPresentMarketingConsentAlert = shouldPresentMarketingConsentAlert
        }
        
        var user: User {
            get {
                guard case let .signedIn(user) = userSessionStatus else { return .dummy }
                return user
            }
            
            set {
                $userSessionStatus.withLock { $0 = .signedIn(newValue) }
            }
        }
    }
    
    enum Action: BindableAction {
        // Binding Actions
        case binding(BindingAction<State>)
        
        // Child Actions
        case pose(PoseCoordinator.Action)
        case archive(ArchiveCoordinator.Action)
        case map(MapCoordinator.Action)
        case myPage(MyPageCoordinator.Action)
        case imagePicker(ImagePickerFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        
        // View Actions
        case onTapAddButton
        case onTapQRScan
        case onTapGallery
        case uploadSelectionSheetDismissed
        
        // Internal Actions
        case qrScannerPresented
        case setPhotosPickerPresented(Bool)
        case presentPermissionAlert
        case dismissPermissionAlert
        case openAppSettings
        case dismissMarketingConsentAlert
        case updateMarketingConsent(Bool)
        case marketingConsentUpdateResponse(Bool, Result<Void, Error>)
        case requestPushNotificationAuthorizationIfNeeded
        case pushNotificationAuthorizationResponse(Result<UNAuthorizationStatus, Error>)
        
        case onAppear
        case tabChanged(NekiTab)
        
        case delegate(Delegate)
        enum Delegate {
            case signedOut
            case withdraw
            case pushNotificationAuthorizationResolved
        }
    }
    
    @Dependency(\.qrScannerClient) private var qrScannerClient
    @Dependency(\.openURL) private var openURL
    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.authClient) private var authClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.archive, action: \.archive) { ArchiveCoordinator() }
        Scope(state: \.pose, action: \.pose) { PoseCoordinator() }
        Scope(state: \.map, action: \.map) { MapCoordinator() }
        Scope(state: \.myPage, action: \.myPage) { MyPageCoordinator() }
        Scope(state: \.imagePicker, action: \.imagePicker) { ImagePickerFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .binding: return .none
                
            case .onAppear:
                if state.selectedTab == .archive,
                   state.shouldPresentMarketingConsentAlert {
                    state.shouldPresentMarketingConsentAlert = false
                    state.isMarketingConsentAlertPresented = true
                    let key = AppStorageKey.marketingConsentAlertPresentationCount(userID: state.user.id)
                    UserDefaults.standard.set(
                        UserDefaults.standard.integer(forKey: key) + 1,
                        forKey: key
                    )
                }
                return .send(.tabChanged(state.selectedTab))
                
            case let .tabChanged(tab):
                return .run { _ in
                    switch tab {
                    case .archive: analyticsClient.logEvent(MainTabAnalyticsEvent.archivingView)
                    case .pose: analyticsClient.logEvent(MainTabAnalyticsEvent.poseView)
                    case .map: analyticsClient.logEvent(MainTabAnalyticsEvent.mapView)
                    default: break
                    }
                }
                
            case .onTapAddButton:
                state.destination = .uploadSelection
                return .none
                
            case .onTapGallery:
                guard state.destination != nil else { return .none }
                state.pendingPresentation = .gallery
                state.destination = nil
                return .none
                
            case .uploadSelectionSheetDismissed:
                guard let pendingPresentation = state.pendingPresentation else { return .none }
                state.pendingPresentation = nil
                switch pendingPresentation {
                case .gallery: return .send(.setPhotosPickerPresented(true))
                }
                
            case let .setPhotosPickerPresented(isPresented):
                state.isPhotoPickerPresented = isPresented
                return .none
                
            case .onTapQRScan:
                state.destination = nil
                switch qrScannerClient.checkAuthorizationStatus() {
                case .authorized: return .send(.qrScannerPresented)
                case .notDetermined:
                    return .run { send in
                        let isAuthorized = await qrScannerClient.requestAccess()
                        guard isAuthorized else { return await send(.presentPermissionAlert) }
                        await send(.qrScannerPresented)
                    }
                    
                case .denied, .restricted:
                    return .send(.presentPermissionAlert)
                    
                @unknown default:
                    return .none
                }
                
            case .qrScannerPresented:
                state.destination = .qrScan(QRCodeScanFeature.State(user: state.user))
                return .none
                
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

            case .dismissMarketingConsentAlert:
                guard state.isUpdatingMarketingConsent == false else { return .none }
                state.isMarketingConsentAlertPresented = false
                return .none

            case let .updateMarketingConsent(isAgreed):
                guard state.isUpdatingMarketingConsent == false else { return .none }
                state.isUpdatingMarketingConsent = true
                return .run { send in
                    await send(.marketingConsentUpdateResponse(
                        isAgreed,
                        Result { try await authClient.updateMarketingConsent(isAgreed) }
                    ))
                }

            case let .marketingConsentUpdateResponse(isAgreed, .success):
                state.isUpdatingMarketingConsent = false
                state.isMarketingConsentAlertPresented = false
                state.user.marketingTermAgreed = isAgreed
                return .send(.requestPushNotificationAuthorizationIfNeeded)

            case .marketingConsentUpdateResponse(_, .failure):
                state.isUpdatingMarketingConsent = false
                return .none

            case .requestPushNotificationAuthorizationIfNeeded:
                return .run { send in
                    await send(.pushNotificationAuthorizationResponse(Result {
                        let status = try await pushNotificationClient.checkAuthorizationStatus()
                        guard status == .notDetermined else { return status }
                        _ = try await pushNotificationClient.requestAuthorization()
                        return try await pushNotificationClient.checkAuthorizationStatus()
                    }))
                }

            case .pushNotificationAuthorizationResponse(.success):
                return .send(.delegate(.pushNotificationAuthorizationResolved))

            case .pushNotificationAuthorizationResponse(.failure):
                return .none
                
            case .archive(.delegate(.requestQRScan)), .pose(.delegate(.requestQRScan)):
                state.destination = nil
                return .send(.onTapQRScan)

            case .archive(.delegate(.requestNotificationList)),
                 .pose(.delegate(.requestNotificationList)),
                 .myPage(.delegate(.requestNotificationList)):
                state.destination = .notificationList(.init())
                return .none
                
            case let .archive(.delegate(.showToast(item))):
                state.toast = item
                return .none
                
            case let .map(.delegate(.showToast(item))):
                state.toast = item
                return .none
                
            case .myPage(.delegate(.didLogout)):
                return .run { send in
                    await send(.archive(.root(.clearData)))
                    await send(.delegate(.signedOut))
                }
                
            case .myPage(.delegate(.didWithdraw)):
                return .run { send in
                    await send(.archive(.root(.clearData)))
                    await send(.delegate(.withdraw))
                }
                
            case let .imagePicker(.delegate(.imagesConverted(entities))):
                state.isPhotoPickerPresented = false
                state.isLoading = false
                state.selectedTab = .archive
                guard !entities.isEmpty else { return .none }
                return .send(.archive(.root(.processUploadImages(entities: entities, appGroupID: nil))))
                
            case let .destination(.presented(.qrScan(.addPhotoFromQRScanner(imageID)))):
                state.destination = nil
                state.selectedTab = .archive
                return .send(.archive(.root(.addPhotoFromQRScanner(imageID: imageID))))
                
            case .destination(.presented(.qrScan(.addPhotoFromGalleryButtonTapped))):
                state.destination = nil
                return .run { send in
                    await send(.onTapGallery)
                    await send(.setPhotosPickerPresented(true))
                }
                
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch state.selectedTab {
            case .archive: state.isTabbarHidden = !state.archive.path.isEmpty
            case .pose: state.isTabbarHidden = !state.pose.path.isEmpty
            case .add: return .none
            case .map: state.isTabbarHidden = !state.map.path.isEmpty
            case .myPage: state.isTabbarHidden = !state.myPage.path.isEmpty
            }
            return .none
        }
    }
}

extension MainTabCoordinator {
    @Reducer
    enum Destination {
        case uploadSelection
        case qrScan(QRCodeScanFeature)
        case notificationList(PushNotificationListFeature)
    }
    enum PendingPresentation {
        case gallery
    }
}
