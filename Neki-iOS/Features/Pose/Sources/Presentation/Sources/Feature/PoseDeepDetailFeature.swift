//
//  PoseDeepDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct PoseDeepDetailFeature {
    
    @ObservableState
    struct State: Equatable {
        let item: FeedImageItem
    }
    
    enum Action {
        // Navigation Action
        case didTapPopToRoot
        case didTapBackButton
        case didTapLogoutButton
        case delegate(Delegate)
        
        enum Delegate {
            case logout
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .didTapLogoutButton:
                return .send(.delegate(.logout))
                
            default:
                return .none
            }
        }
    }
    
}
