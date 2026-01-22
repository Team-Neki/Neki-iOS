//
//  ArchiveFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
//import Core

@Reducer
struct ArchiveFeature {
    
    @ObservableState
    struct State {
        @Shared(.inMemory("archive-photos")) var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        @Shared(.inMemory("archive-albums")) var albums: IdentifiedArrayOf<AlbumItem> = []
        
        var newAlbumTitle: String = ""
        
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
        
        var imagePicker = ImagePickerFeature.State(
            maxCount: 10,
            mediaType: .temp // 테스트를 위한 temp, .photoBooth로 변경 예정
        )
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // User Action
        case onTapAllPhotos
        case onTapAllAlbums
        case onTapQRScan
        
        // 갤러리에서 이미지 선택 시 액션
        case imagePicker(ImagePickerFeature.Action)
        
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        
        // View Life Cycle Action
        case onAppear
        
        // Navigation Action
        case imageTapped(ArchiveImageItem)
        case albumTapped(AlbumItem)
        
        // Delegate Action
        case delegate(DelegateAction)
        enum DelegateAction {
            case showToast(NekiToastItem)
        }
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) {
            ImagePickerFeature()
        }
        
        Reduce { state, action in
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
                
            case .onTapQRScan:
                print("QR 인식")
                return .none
                
            case let .imagePicker(.uploadCompleted(ids)):
                if ids.isEmpty { return .none }
                
                print("✅ [ArchiveFeature] S3 업로드 완료! 획득한 ID 목록: \(ids)")
                
                // TODO: 여기서 id를 서버로 보내는 로직 추가
                
                // (테스트용) 토스트 띄우기
                let toast = NekiToastItem("이미지 \(ids.count)장이 업로드 되었어요 (ID 확인 완료)", style: .success)
                return .send(.delegate(.showToast(toast)))
                
            case .imagePicker(.uploadFailed):
                print("❌ [ArchiveFeature] 업로드 실패")
                let toast = NekiToastItem("업로드에 실패했어요", style: .error)
                return .send(.delegate(.showToast(toast)))
                
            case .onTapCancelAddAlbum:
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
                
                
            default:
                return .none
            }
        }
    }
}

