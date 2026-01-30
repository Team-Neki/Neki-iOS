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
        var selectedCountFilterOption: PeopleCountOption?
        var selectedRandomPoseCountSelectionOption: PeopleCountOption? = .solo
        var sheetItem: PoseView.SheetType? = .randomPoseCountSelection
        var isSelectedScrap: Bool = false
        
        var filteredItems: IdentifiedArrayOf<FeedImageItem> {
            if isSelectedScrap {
                return items.filter { $0.isScrapped }
            } else {
                // TODO: - 인원수 필터 로직 추가
                return items
            }
        }
    }
    
    enum Action: BindableAction {
        // User Action
        case onTapFilter
        case onTapScrap
        case selectPeopleCount(PeopleCountOption)
        case selectPeopleCountForRandomPose(PeopleCountOption)
        
        // View Life Cycle Action
        case onAppear
        
        // Navigation Action
        case imageTapped(FeedImageItem)
        case onTapRandomPoseRecommend
        
        // Binding Action
        case binding(BindingAction<State>)
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            /// 화면전환과 관련된 액션은 default를 이용해 무시하고 나머지 case만 사용
            switch action {
            case .onAppear:
                if state.items.isEmpty {
                    let dummyList = FeedImageItem.dummyData()
                    state.items = IdentifiedArray(uniqueElements: dummyList)
                }
                return .none
                
            case .onTapFilter:
                state.sheetItem = .peopleCountFilter
                return .none
                
            case let .selectPeopleCount(option):
                state.selectedCountFilterOption = state.selectedCountFilterOption == option ? nil : option
                state.isSelectedScrap = false
                return .none
                
            case let .selectPeopleCountForRandomPose(option):
                state.selectedRandomPoseCountSelectionOption = option
                return .none
                
            case .onTapScrap:
                state.selectedCountFilterOption = nil
                state.isSelectedScrap.toggle()
                return .none
                
            case .onTapRandomPoseRecommend:
                state.sheetItem = .randomPoseCountSelection
                return .none
                
            default:
                return .none
            }
        }
    }
}
