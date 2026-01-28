//
//  OnboardingCoordinatorView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import SwiftUI
import ComposableArchitecture

public struct OnboardingCoordinatorView: View {
    @Bindable var store: StoreOf<OnboardingCoordinator>
    
    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            OnboardingView(store: store.scope(state: \.root, action: \.root))
        } destination: { store in
            switch store.case {
            case .termsAgreement(let store):
                TermsAgreementView(store: store)
            }
        }
    }
}

#Preview {
    OnboardingCoordinatorView(store: .init(initialState: OnboardingCoordinator.State(), reducer: { OnboardingCoordinator() }))
}
