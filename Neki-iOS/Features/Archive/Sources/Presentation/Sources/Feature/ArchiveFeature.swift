//
//  ArchiveFeedFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct ArchiveFeature {
    
    @ObservableState
    struct State: Equatable {
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        var albums: IdentifiedArrayOf<AlbumItem> = []
        
        var newAlbumTitle: String = ""
        
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // User Action
        case onTapAllPhotos
        case onTapQRScan
        case onTapAddFromGallery
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
        
        Reduce { state, action in
            /// 화면전환과 관련된 액션은 default를 이용해 무시하고 나머지 case만 사용
            switch action {
            case .onAppear:
                if state.albums.isEmpty {
                    state.albums = IdentifiedArray(uniqueElements: AlbumItem.dummyData())
                }
                if state.photos.isEmpty {
                    state.photos = IdentifiedArray(uniqueElements: ArchiveImageItem.dummyData())
                }
                return .none
                
            case .onTapQRScan:
                print("QR 인식")
                return .none
                
            case .onTapAddFromGallery:
                print("갤러리에서 추가")
                return .none
                
            case .onTapCancelAddAlbum:
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                return .none
                
            case .onTapConfirmAddAlbum:
                guard state.isConfirmButtonEnabled else { return .none }
                
                print("새 앨범 추가됨: \(state.newAlbumTitle)")
                
                let newAlbum = AlbumItem(
                    title: state.newAlbumTitle,
                    count: 0,
                    coverImageURL: nil,         // TODO: - 디자인에서 주는 브랜딩 이미지로 변경
                    isFavorite: false
                )
                
                // 1번째 인덱스에 추가, 0번은 즐겨찾기
                state.albums.insert(newAlbum, at: state.albums.count > 0 ? 1 : 0)
                
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

