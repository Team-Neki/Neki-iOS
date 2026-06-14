//
//  LoginCoordinator.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import Foundation
import ComposableArchitecture
import os

@Reducer
public struct LoginCoordinator {
    @ObservableState
    public struct State {
        var root = LoginFeature.State()
        var path = StackState<Path.State>()
        var pendingUser: User?
    }
    
    public enum Action {
        case root(LoginFeature.Action)
        case path(StackActionOf<Path>)
        
        case delegate(Delegate)
        public enum Delegate {
            case moveToMainTab(User, shouldPresentMarketingConsentAlert: Bool)
        }
    }
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) { LoginFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - Login Flow
            case let .root(.loginResponse(.success(user))):
                if user.allRequiredTermsAgreed {
                    return .send(.delegate(.moveToMainTab(
                        user,
                        shouldPresentMarketingConsentAlert: false
                    )))
                } else {
                    state.pendingUser = user
                    state.path.append(.termsAgreement(.init()))
                    return .none
                }
                
            case let .root(.loginResponse(.failure(error))):
                Logger.presentation.error("로그인 과정 중 에러 발생: \(error)")
                return .none
                
                // MARK: - Onboarding Flow
            case let .path(.element(id, action: .termsAgreement(.didFinishOnboarding(user)))):
                guard state.pendingUser != nil else {
                    Logger.presentation.error("온보딩 과정 중 중단됨.")
                    return .none
                }
                
                state.pendingUser = nil
                state.path.pop(from: id)
                return .send(.delegate(.moveToMainTab(
                    user,
                    shouldPresentMarketingConsentAlert: user.marketingTermAgreed == false
                )))
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}


// MARK: - OnboardingCoordinator + Path

extension LoginCoordinator {
    @Reducer
    public enum Path {
        case termsAgreement(TermsAgreementFeature)
    }
}
