//
//  LoginView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import SwiftUI
import ComposableArchitecture
import AuthenticationServices

public struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>
    
    public init(store: StoreOf<LoginFeature>) { self.store = store }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.primary200.ignoresSafeArea()
            
            authenticationProviders
        }
    }
    
    private var authenticationProviders: some View {
        VStack(spacing: 10) {
            Button {
                store.send(.kakaoLogin)
            } label: {
                Image(.imgKakaoLogin)
                    .resizable()
                    .frame(maxHeight: 56)
            }
            .onOpenURL { store.send(.handleKakaoOpenURL($0)) }
            
            SignInWithAppleButton(.continue) { _ in
                
            } onCompletion: { result in
                store.send(.appleLogin(result))
            }
            .frame(maxHeight: 56)
            .clipShape(.rect(cornerRadius: 12))

        }
        .padding()
    }
}

#Preview {
    LoginView(store: .init(initialState: LoginFeature.State(), reducer: { LoginFeature() }))
}
