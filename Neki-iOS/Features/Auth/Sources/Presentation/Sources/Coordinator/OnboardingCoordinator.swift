//
//  OnboardingCoordinator.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct OnboardingCoordinator {
    @ObservableState
    public struct State {
        var root = OnboardingFeature.State()
        var path = StackState<Path.State>()
    }
    
    public enum Action {
        case root(OnboardingFeature.Action)
        case path(StackActionOf<Path>)
    }
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) { OnboardingFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .path(.element(id, action: .termsAgreement(.didFinishOnboarding))):
                state.root.isOnboardingNeeded = false
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

extension OnboardingCoordinator {
    @Reducer
    public enum Path {
        case termsAgreement(TermsAgreementFeature)
    }
}
