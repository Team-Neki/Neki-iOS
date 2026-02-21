//
//  OnboardingCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 2/6/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingCoordinator {
    @ObservableState
    struct State {
        var currentPage: Int = 1
        
        var originalCount: Int { OnboardingItem.list.count }
        
        var loopedContents: [OnboardingItem] {
            guard let first = OnboardingItem.list.first,
                  let last = OnboardingItem.list.last else { return [] }
            var list = OnboardingItem.list
            list.insert(last, at: 0)
            list.append(first)
            return list
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case startButtonTapped
        
        case checkLoop
        case setPage(Int)
        
        case delegate(Delegate)
        enum Delegate {
            case didFinishOnboarding
        }
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding(\.currentPage):
                return .send(.checkLoop)
                
            case .checkLoop:
                if state.currentPage == 0 {
                    return .run { [count = state.originalCount] send in
                        try? await Task.sleep(for: .milliseconds(200))
                        await send(.setPage(count))
                    }
                }
                else if state.currentPage == state.originalCount + 1 {
                    return .run { send in
                        try? await Task.sleep(for: .milliseconds(200))
                        await send(.setPage(1))
                    }
                }
                return .none
                
            case let .setPage(page):
                state.currentPage = page
                return .none
                
            case .startButtonTapped:
                return .send(.delegate(.didFinishOnboarding))
                
            default:
                return .none
            }
        }
    }
}
