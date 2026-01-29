//
//  ArchiveFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation
//import Core

@Reducer
struct ArchiveFeature {
    
    @ObservableState
    struct State {
        @Shared(.inMemory("archive-photos")) var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        @Shared(.inMemory("archive-albums")) var albums: IdentifiedArrayOf<AlbumItem> = []
        
        @Presents var selectUploadAlbum: SelectUploadAlbumFeature.State?
        @Presents var qrScanner: QRCodeScanFeature.State?
        
        var newAlbumTitle: String = ""
        
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
        
        var showDropDownMenu: Bool = false
        
        var imagePicker = ImagePickerFeature.State(
            maxCount: 10,
            mediaType: .temp // 테스트를 위한 temp, .photoBooth로 변경 예정
        )
        var isLoading: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // User Action
        case toggleDropDownMenu
        case closeDropDownMenu
        case onTapAllPhotos
        case onTapAllAlbums
        case onTapQRScan
        
        // 갤러리에서 이미지 선택 시 액션
        case imagePicker(ImagePickerFeature.Action)
        case selectUploadAlbum(PresentationAction<SelectUploadAlbumFeature.Action>)
        
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        
        // View Life Cycle Action
        case onAppear
        
        // Navigation Action
        case imageTapped(ArchiveImageItem)
        case albumTapped(AlbumItem)
        case afterUploadNavigateToAlbumDetail(AlbumItem)
        case qrScannerPresented
        
        // Internal Action
        case showPermissionAlert
        
        // Delegate Action
        case delegate(DelegateAction)
        enum DelegateAction {
            case showToast(NekiToastItem)
        }
        
        // Child Action
        case qrScanner(PresentationAction<QRCodeScanFeature.Action>)
    }
    
    @Dependency(\.qrScannerClient) private var qrScannerClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) {
            ImagePickerFeature()
        }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            /// 화면전환과 관련된 액션은 default를 이용해 무시하고 나머지 case만 사용
            switch action {
            case .onAppear:
                if state.albums.isEmpty {
                    let loadedAlbums = IdentifiedArray(uniqueElements: AlbumItem.dummyData())
                    state.$albums.withLock { $0 = loadedAlbums }
                }
                if state.photos.isEmpty {
                    let loadedPhotos = IdentifiedArray(uniqueElements: ArchiveImageItem.dummyData())
                    state.$photos.withLock { $0 = loadedPhotos }
                }
                
                return .none
                
            case .toggleDropDownMenu:
                state.showDropDownMenu.toggle()
                return .none
                
            case .closeDropDownMenu:
                state.showDropDownMenu = false
                return .none
                
            case .onTapQRScan:
                defer { state.showDropDownMenu = false }
                switch qrScannerClient.checkAuthorizationStatus() {
                case .authorized:
                    return .send(.qrScannerPresented)
                    
                case .notDetermined:
                    return .run { send in
                        let isAuthorized = await qrScannerClient.requestAccess()
                        guard isAuthorized else { return await send(.showPermissionAlert) }
                        await send(.qrScannerPresented)
                    }
                    
                case .denied, .restricted:
                    return .send(.showPermissionAlert)
                    
                @unknown default:
                    return .none
                }
                
            case .qrScannerPresented:
                state.qrScanner = QRCodeScanFeature.State()
                return .none
                
            case .imagePicker(.uploadStarted):
                state.isLoading = true
                state.showDropDownMenu = false
                return .none
                
            case let .imagePicker(.uploadCompleted(ids)):
                state.isLoading = false
                if ids.isEmpty { return .none }
                
                state.selectUploadAlbum = SelectUploadAlbumFeature.State(
                    uploadedImageIds: ids,
                    albums: state.albums
                )
                return .none
                
            case let .selectUploadAlbum(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .uploadDidSuccess(albumId):
                    state.selectUploadAlbum = nil // 팝업 닫기
                    let toast = NekiToastItem("이미지를 추가했어요", style: .success)
                    
                    // 앨범 선택했다면 해당 앨범으로 이동 요청
                    if let albumId = albumId,
                       let album = state.albums.first(where: { $0.id == albumId }) {
                        return .run { send in
                            await send(.delegate(.showToast(toast)))
                            await send(.afterUploadNavigateToAlbumDetail(album))
                        }
                    }
                    
                    return .send(.delegate(.showToast(toast)))
                }
                
            case .imagePicker(.uploadFailed):
                state.isLoading = false
                print("❌ [ArchiveFeature] 업로드 실패")
                let toast = NekiToastItem("업로드에 실패했어요", style: .error)
                return .send(.delegate(.showToast(toast)))
                
            case .onTapCancelAddAlbum:
                state.showDropDownMenu = false
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                return .none
                
            case .onTapConfirmAddAlbum:
                guard state.isConfirmButtonEnabled else { return .none }
                
                let newAlbum = AlbumItem(
                    title: state.newAlbumTitle,
                    count: 0,
                    coverImageURL: nil,         // TODO: - 디자인에서 주는 브랜딩 이미지로 변경
                    isFavorite: false
                )
                
                state.$albums.withLock {
                    _ = $0.insert(newAlbum, at: 1)
                }
                
                // 입력값 초기화
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                
                let toastItem = NekiToastItem(
                    "새로운 앨범을 추가했어요",
                    style: .success
                )
                
                return .send(.delegate(.showToast(toastItem)))
                
            case .binding(\.newAlbumTitle):
                let inputTitle = state.newAlbumTitle.trimmingCharacters(in: .whitespaces)
                
                if state.albums.contains(where: { $0.title == inputTitle }) {
                    state.albumTitleErrorMessage = "이미 사용 중인 앨범명이에요."
                } else {
                    state.albumTitleErrorMessage = nil
                }
                return .none
                
            case let .qrScanner(.presented(.imageProcessingResult(processedID))):
                state.qrScanner = nil
                // TODO: QR 파싱 후 업로드 끝난 ID를 어떻게 해야하는거지?
                let toast = NekiToastItem("이미지를 추가했어요", style: .success)
                return .send(.delegate(.showToast(toast)))
                
            default:
                return .none
            }
        }
        .ifLet(\.$selectUploadAlbum, action: \.selectUploadAlbum) {
            SelectUploadAlbumFeature()
        }
        .ifLet(\.$qrScanner, action: \.qrScanner) {
            QRCodeScanFeature()
        }
    }
}

