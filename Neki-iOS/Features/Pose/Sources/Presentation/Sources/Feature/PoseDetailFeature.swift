//
//  PoseDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct PoseDetailFeature {
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<FeedImageItem>
        var selectedID: UUID
        var isScrapped: Bool {
            items[id: selectedID]?.isScrapped ?? false
        }
    }
    
    enum Action {
        // User Action
        case onTapScrap
        case pageChanged(UUID)
        
        // Navigation Action
        case didTapBackButton
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTapScrap:
                if state.items[id: state.selectedID] != nil {
                    state.items[id: state.selectedID]?.isScrapped.toggle()
                }
                return .none
                
            case let .pageChanged(newID):
                state.selectedID = newID
                return .none
                
            default:
                return .none
            }
        }
    }
    
}
