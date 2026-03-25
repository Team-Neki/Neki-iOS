//
//  MainTabCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation
// import Pose
// import Archive

@Reducer
struct MainTabCoordinator {
    
    @ObservableState
    struct State {
        var user: User
        var selectedTab: NekiTab = .archive
        
        // 하위 코디네이터들의 State를 보유
        var pose = PoseCoordinator.State()
        var archive = ArchiveCoordinator.State()
        var map = MapCoordinator.State()
        var myPage: MyPageCoordinator.State
        var imagePicker = ImagePickerFeature.State(mediaType: .photoBooth)
        var isPhotoPickerPresented: Bool = false
        var pendingPresentation: PendingPresentation?
        var isLoading: Bool = false

        
        @Presents var destination: Destination.State?
        
        var isTabbarHidden: Bool = false
        var toast: NekiToastItem? = nil
        var isPermissionAlertPresented: Bool = false
        
        init(user: User) {
            self.user = user
            myPage = MyPageCoordinator.State(user: user)
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
        
        case delegate(Delegate)
        enum Delegate {
            case signedOut
            case withdraw
            case profileUpdated(User)
        }
    }
    
    @Dependency(\.qrScannerClient) private var qrScannerClient
    @Dependency(\.openURL) private var openURL
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.archive, action: \.archive) {
            ArchiveCoordinator()
        }
        
        Scope(state: \.pose, action: \.pose) {
            PoseCoordinator()
        }
        
        Scope(state: \.map, action: \.map) {
            MapCoordinator()
        }
        
        Scope(state: \.myPage, action: \.myPage) {
            MyPageCoordinator()
        }
        
        Scope(state: \.imagePicker, action: \.imagePicker) {
            ImagePickerFeature()
        }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .binding:
                return .none
                
            case .onTapAddButton:
                state.destination = .uploadSelection
                return .none
                
                
                // MARK: - Gallary Logic
            case .onTapGallery:
                guard state.destination != nil else { return .none }
                state.pendingPresentation = .gallery
                state.destination = nil
                return .none
                
            case .uploadSelectionSheetDismissed:
                guard let pendingPresentation = state.pendingPresentation else { return .none }
                state.pendingPresentation = nil
                
                switch pendingPresentation {
                case .gallery:
                    return .send(.setPhotosPickerPresented(true))
                }
                
            case let .setPhotosPickerPresented(isPresented):
                state.isPhotoPickerPresented = isPresented
                return .none
                
                // MARK: - QR Scan Logic
            case .onTapQRScan:
                state.destination = nil
                switch qrScannerClient.checkAuthorizationStatus() {
                case .authorized:
                    return .send(.qrScannerPresented)
                    
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
                
                
                // MARK: - Child Features Logic
            case .archive(.delegate(.requestQRScan)):
                state.destination = nil
                return .send(.onTapQRScan)
                
            case let .archive(.delegate(.showToast(item))):
                state.toast = item
                return .none
                
            case .pose(.delegate(.requestQRScan)):
                return .send(.onTapQRScan)
                
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
                
            case let .myPage(.delegate(.profileUpdated(user))):
                return .send(.delegate(.profileUpdated(user)))
                
            case .imagePicker(.uploadStarted):
                state.isLoading = true
                return .none
                
            case let .imagePicker(.uploadCompleted(imageIDs)):
                state.isPhotoPickerPresented = false
                state.isLoading = false
                state.selectedTab = .archive
                guard imageIDs.isEmpty == false else { return .none }
                return .send(.archive(.root(.processUploadImages(imageIDs: imageIDs))))
                
            case .imagePicker(.uploadFailed):
                state.isPhotoPickerPresented = false
                state.isLoading = false
                state.toast = NekiToastItem("이미지 업로드에 실패했어요.", style: .error)
                return .none
                
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
        
        /// 피그마 확인 결과 탭바가 사라지는 모든 case는 depth가 1 이상일 경우더라구요
        /// 즉, 메인 홈 화면에서 depth가 추가되어 넘어가는 뷰들은 전부 탭바가 사라집니다.
        /// 그래서 각 Feature의 state에서 path에 하나라도 추가될 경우 탭바를 가리게 설계했습니다.
        /// 한 가지 문제는, 나중에 depth가 추가되어도 탭바가 보여져야 하는 경우가 생긴다면 다시 머리 싸매야함
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch state.selectedTab {
            case .archive:
                state.isTabbarHidden = !state.archive.path.isEmpty
                
            case .pose:
                state.isTabbarHidden = !state.pose.path.isEmpty
                
            case .add:
                return .none
                
            case .map:
                state.isTabbarHidden = !state.map.path.isEmpty
                
            case .myPage:
                state.isTabbarHidden = !state.myPage.path.isEmpty
            }
            
            return .none
        }
    }
}


// MARK: - Child Reducer

extension MainTabCoordinator {
    @Reducer
    enum Destination {
        case uploadSelection
        case qrScan(QRCodeScanFeature)
    }
}


// MARK: - Nested Types

extension MainTabCoordinator {
    enum PendingPresentation {
        case gallery
    }
}
