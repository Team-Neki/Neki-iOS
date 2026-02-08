//
//  AccountPreferenceFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import Foundation
import ComposableArchitecture
import os

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
        
        // Delegate Actions
        case didSignOut
        case didWithdraw
    }
    
    @Dependency(\.authClient) private var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .logoutButtonTapped:
                return .run { send in
                    try await authClient.signOut()
                    await send(.didSignOut)
                } catch: { error, _ in
                    Logger.presentation.error("로그아웃 과정 중 에러 발생: \(error)")
                }
                
            case .unregisterButtonTapped:
                return .run { [userId = state.user.id] send in
                    try await authClient.withdraw()
                    
                    UserDefaults.standard.removeObject(forKey: "TermsAgreed_\(userId)")
                    
                    await send(.didWithdraw)
                } catch: { error, _ in
                    Logger.presentation.error("회원탈퇴 과정 중 에러 발생: \(error)")
                }
                
            default:
                return .none
            }
        }
    }
}
