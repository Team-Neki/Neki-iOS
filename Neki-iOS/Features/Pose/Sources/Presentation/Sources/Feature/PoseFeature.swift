//
//  PoseFeedFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct PoseFeature {
    
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<FeedImageItem> = []
        var selectedPeopleCount: String? = nil
    }
    
    enum Action {
        case onTapFilter
        case onTapScrap
        case selectPeopleCount(String)
        
        // View Life Cycle Action
        case onAppear
        
        // Navigation Action
        case imageTapped(FeedImageItem)
        case onTapRandomPoseRecommend
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            /// 화면전환과 관련된 액션은 default를 이용해 무시하고 나머지 case만 사용
            switch action {
            case .onAppear:
                if state.items.isEmpty {
                    let dummyList = FeedImageItem.dummyData()
                    state.items = IdentifiedArray(uniqueElements: dummyList)
                }
                return .none
                
            case let .selectPeopleCount(count):
                state.selectedPeopleCount = count
                return .none
                
                
            default:
                return .none
            }
        }
    }
}
