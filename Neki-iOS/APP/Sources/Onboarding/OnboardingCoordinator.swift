//
//  OnboardingCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 2/6/26.
//

import ComposableArchitecture

@Reducer
struct OnboardingCoordinator {
    @ObservableState
    struct State {
        var currentPage: Int = 0
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case startButtonTapped
        
        
        case delegate(Delegate)
        enum Delegate {
            case didFinishOnboarding
        }
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .startButtonTapped:
                return .send(.delegate(.didFinishOnboarding))
                
            default:
                return .none
            }
        }
    }
}
