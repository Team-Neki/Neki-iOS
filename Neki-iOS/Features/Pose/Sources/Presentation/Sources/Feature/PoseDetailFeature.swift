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
    }
    
    enum Action {
        // Navigation Action
        case didTapBackButton
        case didTapDeepLinkButton(FeedImageItem)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            default:
                return .none
            }
        }
    }
    
}
