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
    
    let gradientColor: LinearGradient = LinearGradient(
        colors: [
            .primary500,
            .primary300
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public init(store: StoreOf<LoginFeature>) { self.store = store }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            gradientColor
                .ignoresSafeArea(edges: [.top])
            
            VStack(alignment: .leading, spacing: 0) {
                
                Image(.imgLoginTitle)
                    .padding(.horizontal, 32)
                    .padding(.top, 120)
                
                Spacer()
                
                authenticationProviders
            }
        }
    }
    
    private var authenticationProviders: some View {
        VStack(spacing: 10) {
            Image(.imgAppleLogin)
                .resizable()
                .scaledToFit()
                .overlay {
                    SignInWithAppleButton(.continue) { _ in
                        
                    } onCompletion: { result in
                        store.send(.appleLogin(result))
                    }
                    .blendMode(.destinationOver)
                }
            
            Button {
                store.send(.kakaoLogin)
            } label: {
                Image(.imgKakaoLogin)
                    .resizable()
                    .scaledToFit()
            }
            .onOpenURL { store.send(.handleKakaoOpenURL($0)) }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .background(.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20))
    }
}

#Preview {
    LoginView(store: .init(initialState: LoginFeature.State(), reducer: { LoginFeature() }))
}
