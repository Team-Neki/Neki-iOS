//
//  LoginCoordinatorView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import SwiftUI
import ComposableArchitecture

public struct LoginCoordinatorView: View {
    @Bindable var store: StoreOf<LoginCoordinator>
    
    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            LoginView(store: store.scope(state: \.root, action: \.root))
        } destination: { store in
            switch store.case {
            case .termsAgreement(let store):
                TermsAgreementView(store: store)
            }
        }
    }
}
