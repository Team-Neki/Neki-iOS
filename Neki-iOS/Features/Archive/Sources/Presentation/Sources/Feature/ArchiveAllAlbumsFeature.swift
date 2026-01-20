//
//  ArchiveAllAlbumsFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/20/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ArchiveAllAlbumsFeature {
    
    @ObservableState
    struct State {
        @Shared var albums: IdentifiedArrayOf<AlbumItem>
                
        var newAlbumTitle: String = ""
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onTapBackButton
        
        case onTapAlbum(AlbumItem)
        case onTapDeleteAlbum(AlbumItem)
        
        // 앨범 생성 시트 액션
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        
        // Delegate (부모 코디네이터로 전달)
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case let .onTapDeleteAlbum(album):
                state.$albums.withLock { _ = $0.remove(id: album.id) }
                
                let toastItem = NekiToastItem(
                    "앨범을 삭제했어요",
                    style: .success
                )
                
                return .send(.delegate(.showToast(toastItem)))
                
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
