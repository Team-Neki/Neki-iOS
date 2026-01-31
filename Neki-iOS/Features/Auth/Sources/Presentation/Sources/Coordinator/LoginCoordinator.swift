//
//  LoginCoordinator.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct LoginCoordinator {
    @ObservableState
    public struct State {
        var root = LoginFeature.State()
        var path = StackState<Path.State>()
    }
    
    public enum Action {
        case root(LoginFeature.Action)
        case path(StackActionOf<Path>)
    }
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) { LoginFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .path(.element(id, action: .termsAgreement(.didFinishOnboarding))):
                state.root.$isOnboardingNeeded.withLock { $0 = false }
                state.path.pop(from: id)
                return .none
                
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
