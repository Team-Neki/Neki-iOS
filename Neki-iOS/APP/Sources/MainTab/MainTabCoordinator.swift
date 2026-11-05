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
        
        @Presents var destination: Destination.State?
        
        var isTabbarHidden: Bool = false
        var toast: NekiToastItem? = nil
        var isPermissionAlertPresented: Bool = false
        var isPushNotificationPermissionAlertPresented: Bool = false
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
        
        /// 지금 탭의 첫 화면이 맨 위에 있는지, QR·알림 목록처럼 탭 전체를 덮는 화면이 떠 있는지입니다.
        var firstScreenCoverage: FirstScreenCoverage {
            let isOnTop = switch selectedTab {
            case .archive: archive.path.isEmpty
            case .pose: pose.path.isEmpty
            case .add: false
            case .map: map.path.isEmpty
            case .myPage: myPage.path.isEmpty
            }
            let isCovered = switch destination {
            case .qrScan, .notificationList: true
            case .uploadSelection, .none: false
            }
            return FirstScreenCoverage(tab: selectedTab, isOnTop: isOnTop, isCovered: isCovered)
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
        case requestNotificationList
        case pushNotificationListAuthorizationResponse(Result<UNAuthorizationStatus, Error>)
        case dismissPushNotificationPermissionAlert
        case openAppSettings
        case dismissMarketingConsentAlert
        case updateMarketingConsent(Bool)
        case marketingConsentUpdateResponse(Bool, Result<Void, Error>)
        case route(AppRouteRequest)
        
        case onAppear
        case tabChanged(NekiTab)
        
        case delegate(Delegate)
        enum Delegate {
            case signedOut
            case withdraw
        }
    }
    
    @Dependency(\.qrScannerClient) private var qrScannerClient
    @Dependency(\.openURL) private var openURL
    @Dependency(\.authClient) private var authClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    @Dependency(\.date.now) private var now
    
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
                    recordMarketingConsentAlertPresentation(for: state.user)
                }
                return .send(.tabChanged(state.selectedTab))
                
            case let .tabChanged(tab):
                // 화면 진입 이벤트는 각 탭의 첫 화면이 보일 때 그 화면이 보내므로 여기서는 보내지 않습니다.
                // 지도 탭으로 돌아오면 첫 지도 화면으로 되돌리도록 지도에 알립니다. 초기화는 지도가 맡습니다.
                guard tab == .map else { return .none }
                return .send(.map(.root(.didEnterTab)))
                
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

            case .requestNotificationList:
                return .run { send in
                    await send(.pushNotificationListAuthorizationResponse(Result {
                        let status = try await pushNotificationClient.checkAuthorizationStatus()
                        let resolvedStatus: UNAuthorizationStatus
                        if status == .notDetermined {
                            _ = try await pushNotificationClient.requestAuthorization()
                            resolvedStatus = try await pushNotificationClient.checkAuthorizationStatus()
                        } else {
                            resolvedStatus = status
                        }
                        if resolvedStatus.canPresentNotificationList {
                            _ = try? await pushNotificationClient.synchronizeDeviceToken()
                        }
                        return resolvedStatus
                    }))
                }

            case let .pushNotificationListAuthorizationResponse(.success(status)):
                guard status.canPresentNotificationList else {
                    state.isPushNotificationPermissionAlertPresented = true
                    return .none
                }
                state.destination = .notificationList(.init())
                return .none

            case .pushNotificationListAuthorizationResponse(.failure):
                state.isPushNotificationPermissionAlertPresented = true
                return .none

            case .dismissPushNotificationPermissionAlert:
                state.isPushNotificationPermissionAlertPresented = false
                return .none
                
            case .openAppSettings:
                state.isPermissionAlertPresented = false
                state.isPushNotificationPermissionAlertPresented = false
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }

            case .dismissMarketingConsentAlert:
                guard state.isUpdatingMarketingConsent == false else { return .none }
                state.isMarketingConsentAlertPresented = false
                recordMarketingConsentManaged(
                    for: state.user,
                    status: .unconfirmed
                )
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
                recordMarketingConsentManaged(
                    for: state.user,
                    status: isAgreed ? .approved : .rejected
                )
                return .none

            case .marketingConsentUpdateResponse(_, .failure):
                state.isUpdatingMarketingConsent = false
                return .none

            case let .route(request):
                return route(state: &state, to: request)
                
            case .archive(.delegate(.requestQRScan)), .pose(.delegate(.requestQRScan)):
                state.destination = nil
                return .send(.onTapQRScan)

            case .archive(.delegate(.requestNotificationList)),
                 .pose(.delegate(.requestNotificationList)),
                 .myPage(.delegate(.requestNotificationList)):
                return .send(.requestNotificationList)
                
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
        .onChange(of: \.firstScreenCoverage) { oldValue, state in
            // QR·알림 목록이 닫혀도 아래 탭 첫 화면의 onAppear는 다시 불리지 않습니다.
            // 탭과 화면이 그대로인 채 닫혀 첫 화면이 다시 보이면, 그 화면에 알려 화면 진입을 남기게 합니다.
            // 닫히면서 탭이 바뀌거나 첫 화면으로 돌아가면 다시 그려지는 첫 화면의 onAppear가 남기므로 알리지 않습니다.
            let newValue = state.firstScreenCoverage
            guard oldValue.isCovered, newValue.isCovered == false,
                  oldValue.tab == newValue.tab, oldValue.isOnTop, newValue.isOnTop else { return .none }
            
            switch newValue.tab {
            case .archive: return .send(.archive(.root(.fullScreenCoverDismissed)))
            case .pose: return .send(.pose(.root(.fullScreenCoverDismissed)))
            case .map: return .send(.map(.root(.fullScreenCoverDismissed)))
            case .add, .myPage: return .none
            }
        }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch state.selectedTab {
            case .archive: state.isTabbarHidden = !state.archive.path.isEmpty
            case .pose: state.isTabbarHidden = !state.pose.path.isEmpty
            case .add: return .none
            case .map: state.isTabbarHidden = state.map.hidesTabBar
            case .myPage: state.isTabbarHidden = !state.myPage.path.isEmpty
            }
            return .none
        }
    }
}

private extension MainTabCoordinator {
    func recordMarketingConsentAlertPresentation(for user: User) {
        let countKey = AppStorageKey.marketingConsentAlertPresentationCount(userID: user.id)
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: countKey) + 1,
            forKey: countKey
        )
        recordMarketingConsentManaged(for: user, status: .unconfirmed)
    }

    func recordMarketingConsentManaged(
        for user: User,
        status: MarketingConsentManagementStatus
    ) {
        UserDefaults.standard.set(
            now,
            forKey: AppStorageKey.marketingConsentLastManagedAt(userID: user.id)
        )
        UserDefaults.standard.set(
            status.rawValue,
            forKey: AppStorageKey.marketingConsentManagementStatus(userID: user.id)
        )
    }

    func route(
        state: inout MainTabCoordinator.State,
        to request: AppRouteRequest
    ) -> Effect<MainTabCoordinator.Action> {
        state.destination = nil

        switch request {
        case .archive:
            state.selectedTab = .archive
            state.archive.path.removeAll()
            return .none

        case .archivePhoto(_):
            state.selectedTab = .archive
            state.archive.path.removeAll()
            return .none

        case .pose:
            state.selectedTab = .pose
            state.pose.path.removeAll()
            return .none

        case .map, .mapBrand(_), .mapBooth(_):
            state.selectedTab = .map
            state.map.path.removeAll()
            return .none

        case .myPage:
            state.selectedTab = .myPage
            state.myPage.path.removeAll()
            return .none

        case .notificationList:
            state.destination = .notificationList(.init())
            return .none

        case let .shareExtension(appGroupID):
            state.selectedTab = .archive
            state.archive.path.removeAll()
            return .send(.archive(.root(.addPhotoFromShareExtension(appGroupID: appGroupID))))
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
    /// 탭 첫 화면을 덮었던 화면이 닫혀 그 첫 화면이 다시 보이는지 판단하려고 액션 전후로 비교하는 값입니다.
    struct FirstScreenCoverage: Equatable {
        let tab: NekiTab
        let isOnTop: Bool
        let isCovered: Bool
    }
}

private extension UNAuthorizationStatus {
    var canPresentNotificationList: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied: false
        @unknown default: false
        }
    }
}
