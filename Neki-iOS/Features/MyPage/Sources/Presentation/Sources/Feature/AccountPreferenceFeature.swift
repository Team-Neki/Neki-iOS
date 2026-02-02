//
//  AccountPreferenceFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import Foundation
import ComposableArchitecture

@Reducer
struct AccountPreferenceFeature {
    @ObservableState
    struct State {
        var user: User
    }
    
    enum Action {
        // View Actions
        case editProfileButtonTapped
        case logoutButtonTapped
        case unregisterButtonTapped
    }
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .logoutButtonTapped:
                return .none
                
            case .unregisterButtonTapped:
                return .none
                
            default:
                return .none
            }
        }
    }
}
