//
//  TermsAgreementFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation
import ComposableArchitecture
import os

@Reducer
public struct TermsAgreementFeature {
    @ObservableState
    public struct State {
        var agreements: IdentifiedArrayOf<UserAgreement> = []
        var isAllAgreed: Bool { agreements.allSatisfy(\.isAgreed) }
        var isConfirmButtonEnabled: Bool { agreements.filter(\.term.isRequired).allSatisfy(\.isAgreed) }
        var isLoading: Bool = false
    }
    
    public enum Action: BindableAction {
        // View Actions
        case onAppear
        case toggleAgreement(UserAgreement)
        case toggleAllAgreements
        case confirmButtonTapped
        case termPageLinkTapped(UserAgreement)
        
        // Internal Actions
        case fetchTermsResponse(Result<[Term], Error>)
        case agreeTermsResponse(Result<User, Error>)
        
        // Delegate Actions
        case didFinishOnboarding(User)
        
        // Binding Action
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.openURL) private var openURL
    @Dependency(\.authClient) private var authClient
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.fetchTermsResponse(Result { try await authClient.fetchTerms() }))
                }
                
            case let .toggleAgreement(agreement):
                state.agreements[id: agreement.id]?.isAgreed.toggle()
                return .none
                
            case .toggleAllAgreements:
                let shouldAgreeAll = state.isAllAgreed == false
                for id in state.agreements.ids { state.agreements[id: id]?.isAgreed = shouldAgreeAll }
                return .none
                
            case .confirmButtonTapped:
                guard state.isConfirmButtonEnabled, state.isLoading == false else { return .none }
                state.isLoading = true
                let agreementsToSend = Array(state.agreements)
                
                return .run { send in
                    await send(.agreeTermsResponse(Result {
                        try await authClient.agreeWithTerms(agreementsToSend)
                        return try await authClient.fetchUser()
                    }))
                }
                
            case let .fetchTermsResponse(.success(terms)):
                let userAgreements = terms.map { UserAgreement(term: $0) }
                state.agreements = IdentifiedArray(uniqueElements: userAgreements)
                state.isLoading = false
                return .none
                
            case let .fetchTermsResponse(.failure(error)):
                state.isLoading = false
                Logger.presentation.error("Error occured while fetching terms: \(error)")
                return .none
                
            case let .agreeTermsResponse(.success(user)):
                state.isLoading = false
                return .send(.didFinishOnboarding(user))
                
            case let .agreeTermsResponse(.failure(error)):
                state.isLoading = false
                Logger.presentation.error("Error occured while agreeing to terms: \(error)")
                return .none
                
            case let .termPageLinkTapped(agreement):
                return .run { _ in
                    guard let url = agreement.term.termInformationURL else { return }
                    await openURL(url)
                }
                
            default:
                return .none
            }
        }
    }
}
