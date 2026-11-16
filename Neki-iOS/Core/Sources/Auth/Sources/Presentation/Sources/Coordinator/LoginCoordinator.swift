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
        var pendingLoginResult: AuthLoginResult?
    }
    
    public enum Action {
        case root(LoginFeature.Action)
        case path(StackActionOf<Path>)
        
        case delegate(Delegate)
        public enum Delegate {
            case moveToMainTab(User, completion: Completion)
        }
    }
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) { LoginFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - Login Flow
            case let .root(.loginResponse(.success(loginResult))):
                guard loginResult.user.allRequiredTermsAgreed else {
                    state.pendingLoginResult = loginResult
                    state.path.append(.termsAgreement(.init()))
                    return .none
                }
                return .send(.delegate(.moveToMainTab(loginResult.user, completion: .loggedIn)))
                
            case let .root(.loginResponse(.failure(error))):
                Logger.presentation.error("로그인 과정 중 에러 발생: \(error)")
                return .none
                
                // MARK: - Onboarding Flow
            case let .path(.element(id, action: .termsAgreement(.didFinishOnboarding(user, isMarketingTermAgreed)))):
                guard state.pendingLoginResult != nil else {
                    Logger.presentation.error("온보딩 과정 중 중단됨.")
                    return .none
                }
                
                state.pendingLoginResult = nil
                state.path.pop(from: id)
                return .send(.delegate(.moveToMainTab(
                    user,
                    completion: .agreedToTerms(isMarketingTermAgreed: isMarketingTermAgreed)
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

// MARK: - LoginCoordinator + Completion

extension LoginCoordinator {
    /// 로그인이 어떻게 끝났는지입니다. Auth가 아는 정보만 담습니다.
    public enum Completion: Equatable, Sendable {
        /// 약관 화면 없이 로그인했습니다.
        case loggedIn
        /// 약관 동의를 마치고 로그인했습니다. (선택) 이벤트·혜택 알림 약관에 체크했는지 함께 담습니다.
        case agreedToTerms(isMarketingTermAgreed: Bool)
    }
}
