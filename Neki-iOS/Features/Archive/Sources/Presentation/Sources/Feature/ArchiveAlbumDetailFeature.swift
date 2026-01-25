//
//  ArchiveAlbumDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ArchiveAlbumDetailFeature {
    
    @ObservableState
    struct State {
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        let album: AlbumItem
        
        var selectedIDs: Set<Int> = []
        var deleteOption: ArchivePhotoDeleteOption = .fromAlbumOnly
        
        var selectedSortedTime: String = "최신순"
        var isSelectedFavorite: Bool = false
        var isSelectionMode: Bool = false
        
        var hasSelectedItems: Bool { !selectedIDs.isEmpty }
        
        // 현재는 더미라 전체 photos 사용
        var filteredItems: IdentifiedArrayOf<ArchiveImageItem> {
            var items = photos // TODO: 여기서 앨범 ID로 1차 필터링 필요
            
            if isSelectedFavorite {
                items = items.filter { $0.isFavorite }
            }
            
            let sorted = items.sorted { item1, item2 in
                if selectedSortedTime == "최신순" {
                    return item1.date > item2.date
                } else {
                    return item1.date < item2.date
                }
            }
            return IdentifiedArray(uniqueElements: sorted)
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        
        // 기능 액션
        case onTapDownloadButton
        case onTapDeleteButton
        case onTapFilterNewest
        case onTapFilterOldest
        case onTapFavoriteButton
        
        // 네비게이션
        case imageTapped(ArchiveImageItem)
        
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
                
            case .onTapSelectButton:
                state.isSelectionMode = true
                return .none
                
            case .onTapCancelSelectButton:
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .none
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if state.selectedIDs.contains(item.id) {
                        state.selectedIDs.remove(item.id)
                    } else {
                        state.selectedIDs.insert(item.id)
                    }
                }
                return .none
                
            case .onTapDownloadButton:
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success))))
                
            case .onTapDeleteButton:
                switch state.deleteOption {
                case .everywhere:
                    // 모든 위치에서 제거 (원본 데이터 삭제)
                    state.$photos.withLock { photos in
                        photos.removeAll { state.selectedIDs.contains($0.id) }
                    }
                    
                case .fromAlbumOnly:
                    // 앨범에서만 제거
                    print("앨범 매핑 해제")
                }
                
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                state.deleteOption = .fromAlbumOnly
                
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
            case .onTapFilterNewest:
                state.selectedSortedTime = "최신순"
                return .none
                
            case .onTapFilterOldest:
                state.selectedSortedTime = "오래된순"
                return .none
                
            case .onTapFavoriteButton:
                state.isSelectedFavorite.toggle()
                return .none
                
            default:
                return .none
            }
        }
    }
}
