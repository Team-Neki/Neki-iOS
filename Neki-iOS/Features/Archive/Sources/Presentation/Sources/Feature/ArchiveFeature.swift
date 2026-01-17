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
        var showTooltip: Bool = true
    }
    
    enum Action {
        // User Action
        case tapAllPhotos
        case tapAddButton
        case closeTooltip
        
        // View Life Cycle Action
        case onAppear
        
        // Navigation Action
        case imageTapped(ArchiveImageItem)
        case albumTapped(AlbumItem)
    }
    
    var body: some ReducerOf<Self> {
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
                
            default:
                return .none
            }
        }
    }
}

