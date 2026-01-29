//
//  TermsAgreementFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct TermsAgreementFeature {
    @ObservableState
    public struct State {
        var agreements: IdentifiedArrayOf<UserAgreement>
        var isAllAgreed: Bool { agreements.allSatisfy(\.isAgreed) }
        var isConfirmButtonEnabled: Bool { agreements.filter(\.isRequired).allSatisfy(\.isAgreed) }
        
        public init() {
            self.agreements = [
                UserAgreement(type: .serviceUsage),
                UserAgreement(type: .privacyPolicy),
                UserAgreement(type: .locationService)
            ]
        }
    }
    
    public enum Action: BindableAction {
        // View Actions
        case toggleAgreement(TermsType)
        case toggleAllAgreements
        case confirmButtonTapped
        
        // Delegate Actions
        case didFinishOnboarding
        
        // Binding Action
        case binding(BindingAction<State>)
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .toggleAgreement(type):
                state.agreements[id: type]?.isAgreed.toggle()
                return .none
                
            case .toggleAllAgreements:
                let shouldAgreeAll = state.isAllAgreed == false
                for type in TermsType.allCases { state.agreements[id: type]?.isAgreed = shouldAgreeAll }
                return .none
                
            case .confirmButtonTapped:
                guard state.isConfirmButtonEnabled else { return .none }
                return .send(.didFinishOnboarding)
                
            default:
                return .none
            }
        }
    }
}
