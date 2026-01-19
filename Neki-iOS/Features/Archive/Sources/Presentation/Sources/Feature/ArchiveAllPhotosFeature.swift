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
        
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        
        var selectedSortedTime: String = "최신순"
        var isSelectedFavorite: Bool = false
        var isSelectionMode: Bool = true
        
        // 선택된 사진이 있는지 여부
        var hasSelectedItems: Bool {
            return photos.contains { $0.isSelected }
        }
        
        var filteredItems: IdentifiedArrayOf<ArchiveImageItem> {
            if isSelectedFavorite {
                return photos.filter { $0.isScrapped }
            } else {
                // TODO: - 최신순 오래된 순 정렬 로직 추가
                return photos
            }
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
                for i in 0..<state.photos.count {
                    state.photos[i].isSelected = false
                }
                return .none
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if let index = state.photos.index(id: item.id) {
                        state.photos[index].isSelected.toggle()
                    }
                } else {
                    // 상세 화면으로 이동 (ArchiveCoordinator에서 처리)
                }
                return .none
                
            case .onTapDownloadButton:
                // TODO: - 다운로드 로직 구현
                let selectedItems = state.photos.filter { $0.isSelected }
                print("다운로드할 항목: \(selectedItems.count)개")
                return .none
                
            case .onTapDeleteButton:
                // TODO: - 삭제 로직 구현 및 알림 표시
                let selectedItems = state.photos.filter { $0.isSelected }
                print("삭제할 항목: \(selectedItems.count)개")
                return .none
                
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
