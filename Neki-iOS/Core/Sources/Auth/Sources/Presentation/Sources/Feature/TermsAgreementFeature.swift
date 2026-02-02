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
        case termPageLinkTapped(TermsType)
        
        // Delegate Actions
        case didFinishOnboarding
        
        // Binding Action
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.openURL) private var openURL
    
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
                
            case let .termPageLinkTapped(type):
                let urlString: String
                switch type {
                case .serviceUsage: urlString = "https://lydian-tip-26b.notion.site/2ee0d9441db0807c8684ce3e2d4b8aca?source=copy_link"
                case .privacyPolicy: urlString = "https://lydian-tip-26b.notion.site/2ee0d9441db0807cb850f78145db6dd3?pvs=74"
                case .locationService: urlString = "https://lydian-tip-26b.notion.site/2ee0d9441db080b48223fb0b3263da08?pvs=74"
                }
                return .run { _ in
                    guard let url = URL(string: urlString) else { return }
                    await openURL(url)
                }
                
            default:
                return .none
            }
        }
    }
}
