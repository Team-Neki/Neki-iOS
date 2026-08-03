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
            case moveToMainTab(
                User,
                registrationStatus: RegistrationStatus,
                shouldPresentMarketingConsentAlert: Bool,
                didCompleteTermsAgreement: Bool,
                marketingConsentStatus: MarketingConsentManagementStatus?
            )
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
                return .send(.delegate(.moveToMainTab(
                    loginResult.user,
                    registrationStatus: loginResult.registrationStatus,
                    shouldPresentMarketingConsentAlert: false,
                    didCompleteTermsAgreement: false,
                    marketingConsentStatus: nil
                )))
                
            case let .root(.loginResponse(.failure(error))):
                Logger.presentation.error("로그인 과정 중 에러 발생: \(error)")
                return .none
                
                // MARK: - Onboarding Flow
            case let .path(.element(id, action: .termsAgreement(.didFinishOnboarding(user, marketingConsentStatus)))):
                guard let pendingLoginResult = state.pendingLoginResult else {
                    Logger.presentation.error("온보딩 과정 중 중단됨.")
                    return .none
                }
                
                state.pendingLoginResult = nil
                state.path.pop(from: id)
                return .send(.delegate(.moveToMainTab(
                    user,
                    registrationStatus: pendingLoginResult.registrationStatus,
                    shouldPresentMarketingConsentAlert: marketingConsentStatus == nil && user.marketingTermAgreed == false,
                    didCompleteTermsAgreement: true,
                    marketingConsentStatus: marketingConsentStatus
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
