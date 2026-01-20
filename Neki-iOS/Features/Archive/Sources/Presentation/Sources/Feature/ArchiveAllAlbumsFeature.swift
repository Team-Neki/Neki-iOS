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
        
        var isDeleteMode: Bool = false
        var selectedAlbumIDs: Set<UUID> = []
        var deleteOption: ArchiveDeleteSheet.ArchiveDeleteOption = .withPhotos
                
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
        
        case onTapEnterDeleteMode
        case onTapExitDeleteMode
        case onTapToggleSelection(AlbumItem)
        case onTapExecuteDelete
        
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
                if state.isDeleteMode {
                    return .send(.onTapExitDeleteMode)
                } else {
                    return .run { _ in await dismiss() }
                }
                
            case .onTapEnterDeleteMode:
                state.isDeleteMode = true
                state.selectedAlbumIDs.removeAll()
                return .none
                            
            case .onTapExitDeleteMode:
                state.isDeleteMode = false
                state.selectedAlbumIDs.removeAll()
                return .none
                
            case let .onTapToggleSelection(album):
                guard !album.isFavorite else { return .none }
                
                if state.selectedAlbumIDs.contains(album.id) {
                    state.selectedAlbumIDs.remove(album.id)
                } else {
                    state.selectedAlbumIDs.insert(album.id)
                }
                return .none
                
            case .onTapExecuteDelete:
                guard !state.selectedAlbumIDs.isEmpty else {
                    return .send(.onTapExitDeleteMode)
                }
                
                // TODO: - 삭제 옵션에 따라 앨범만 삭제하고 이미지들은 유지 혹은 앨범과 이미지 모두 삭제 로직
                                
                state.$albums.withLock { albums in
                    albums.removeAll { state.selectedAlbumIDs.contains($0.id) }
                }
                
                state.isDeleteMode = false
                state.selectedAlbumIDs.removeAll()
                
                let toastItem = NekiToastItem("앨범을 삭제했어요", style: .success)
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
