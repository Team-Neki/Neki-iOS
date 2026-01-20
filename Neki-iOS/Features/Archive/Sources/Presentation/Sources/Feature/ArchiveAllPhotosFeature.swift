//
//  ArchiveAllPhotosFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/19/26.
//

import ComposableArchitecture
import Foundation
//import Core

@Reducer
struct ArchiveAllPhotosFeature {
    
    @ObservableState
    struct State {
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        var selectedIDs: Set<UUID> = []
        
        var selectedSortedTime: String = "최신순"
        var isSelectedFavorite: Bool = false
        var isSelectionMode: Bool = false
        
        // 선택된 사진이 있는지 여부
        var hasSelectedItems: Bool {
            return !selectedIDs.isEmpty
        }
        
        var filteredItems: IdentifiedArrayOf<ArchiveImageItem> {
            let filtered = isSelectedFavorite ? photos.filter { $0.isFavorite } : photos
            
            let sorted = filtered.sorted { item1, item2 in
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
        case onTapDownloadButton
        case onTapDeleteButton
        
        case onTapFilterNewest
        case onTapFilterOldest
        case onTapFavoriteButton
        
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
                // 선택 모드 해제 시 모든 선택 상태 초기화
                state.selectedIDs.removeAll()
                return .none
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if state.selectedIDs.contains(item.id) {
                        state.selectedIDs.remove(item.id)
                    } else {
                        state.selectedIDs.insert(item.id)
                    }
                } else {
                    // 상세 화면 이동 로직 (Coordinator에서 처리)
                }
                return .none
                
            case .onTapDownloadButton:
                // TODO: - 다운로드 로직 구현
                let selectedItems = state.photos.filter { state.selectedIDs.contains($0.id) }
                print("다운로드할 항목: \(selectedItems.count)개")
                let toast = NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success)
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(toast)))
                
            case .onTapDeleteButton:
                // TODO: - 삭제 로직 구현 및 알림 표시
                state.$photos.withLock {
                    $0.removeAll { state.selectedIDs.contains($0.id) }
                }
                let toast = NekiToastItem("사진을 삭제했어요", style: .success)
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(toast)))
                
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
