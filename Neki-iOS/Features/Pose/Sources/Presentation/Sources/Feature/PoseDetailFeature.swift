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
        let item: FeedImageItem
        var isScrapped: Bool = false
    }
    
    enum Action {
        // User Action
        case onTapScrap
        
        // Navigation Action
        case didTapBackButton
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTapScrap:
                state.isScrapped.toggle()
                return .none
                
            default:
                return .none
            }
        }
    }
    
}
