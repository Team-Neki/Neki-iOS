//
//  PoseFeedFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct PoseFeedFeature {
    
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<FeedImageItem> = []
    }
    
    enum Action {
        case onAppear
        case imageTapped(FeedImageItem)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.items.isEmpty {
                    let dummyList = FeedImageItem.dummyData()
                    state.items = IdentifiedArray(uniqueElements: dummyList)
                }
                return .none
                
            case let .imageTapped(item):
                print("Tapped item ID: \(item.id)")
                return .none
            }
        }
    }
}
