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
                // TODO: 선택 모드 진입 로직 구현
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
                
            case .imageTapped(let item):
                // 상세 화면으로 이동하거나 선택 로직
                return .none
                
            default:
                return .none
            }
        }
    }
}
