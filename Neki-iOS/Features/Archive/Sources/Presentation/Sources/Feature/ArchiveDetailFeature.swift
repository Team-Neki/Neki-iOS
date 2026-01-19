//
//  ArchiveDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct ArchiveDetailFeature {
    @ObservableState
    struct State: Equatable {
        let item: ArchiveImageItem
    }
    
    enum Action {
        // Navigation Action
        case didTapBackButton
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
