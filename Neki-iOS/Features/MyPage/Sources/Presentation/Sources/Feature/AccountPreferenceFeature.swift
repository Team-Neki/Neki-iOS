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
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut
        
        var isLogoutAlertPresented: Bool = false
        var isUnregisterAlertPresented: Bool = false
        var isLoading: Bool = false
        
        var user: User {
            guard case let .signedIn(user) = userSessionStatus else { return .dummy }
            return user
        }
    }
    
    enum Action: BindableAction {
        // View Actions
        case logoutMenuTapped
        case unregisterMenuTapped
        case logoutButtonTapped
        case unregisterButtonTapped
        case cancelButtonTapped
        case editProfileButtonTapped
        
        // Internal Actions
        case onLoading(Bool)
        case signOutSucceeded
        case withdrawSucceeded
        
        // Delegate Actions
        case didSignOut
        case didWithdraw
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.authClient) private var authClient
    @Dependency(\.analyticsClient) private var analytics
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .logoutMenuTapped:
                state.isLogoutAlertPresented = true
                return .none
                
            case .unregisterMenuTapped:
                state.isUnregisterAlertPresented = true
                return .none
                
            case .logoutButtonTapped:
                state.isLogoutAlertPresented = false
                state.isLoading = true
                
                return .run { send in
                    try await authClient.signOut()
                    await send(.signOutSucceeded)
                } catch: { error, send in
                    Logger.presentation.error("로그아웃 과정 중 에러 발생: \(error)")
                    await send(.onLoading(false))
                }
                
            case .unregisterButtonTapped:
                state.isUnregisterAlertPresented = false
                state.isLoading = true
                
                return .run { [userID = state.user.id] send in
                    try await authClient.withdraw()
                    UserDefaults.standard.removeObject(forKey: "TermsAgreed_\(userID)")
                    await send(.withdrawSucceeded)
                } catch: { error, send in
                    Logger.presentation.error("회원탈퇴 과정 중 에러 발생: \(error)")
                    await send(.onLoading(false))
                }
                
            case .cancelButtonTapped:
                state.isLogoutAlertPresented = false
                state.isUnregisterAlertPresented = false
                return .none
                
            case .signOutSucceeded:
                return .run { send in
                    await analytics.endUserSession(MyPageAnalyticsEvent.logout)
                    await send(.didSignOut)
                }
                
            case .withdrawSucceeded:
                return .run { send in
                    await analytics.endUserSession(MyPageAnalyticsEvent.withdraw)
                    await send(.didWithdraw)
                }

            case .didSignOut, .didWithdraw:
                state.isLoading = false
                return .none
                
            case .onLoading(let isLoading):
                state.isLoading = isLoading
                return .none
                
            default:
                return .none
            }
        }
    }
}
