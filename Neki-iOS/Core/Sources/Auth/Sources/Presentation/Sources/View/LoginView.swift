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
        .nekiLoading(isPresented: store.isLoading)
        .task { await store.send(.onAppear).finish() }
    }
    
    private var authenticationProviders: some View {
        VStack(spacing: 10) {
            appleLoginButton
            
            kakaoLoginButton
        }
        .allowsHitTesting(store.advertisingTrackingAuthorizationPhase == .resolved)
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .background(.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20))
    }

    private var appleLoginButton: some View {
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
            .recentLoginBadge(provider: .apple, isPresented: store.recentLoginProvider == .apple)
    }

    private var kakaoLoginButton: some View {
        Button {
            store.send(.kakaoLogin)
        } label: {
            Image(.imgKakaoLogin)
                .resizable()
                .scaledToFit()
        }
        .recentLoginBadge(provider: .kakao, isPresented: store.recentLoginProvider == .kakao)
        .onOpenURL { store.send(.handleKakaoOpenURL($0)) }
    }
}


// MARK: - RecentLoginBadge

private struct RecentLoginBadgeModifier: ViewModifier {
    let provider: ProviderType
    let isPresented: Bool

    private var foregroundColor: Color {
        provider == .apple ? .gray900 : .white
    }

    private var backgroundColor: Color {
        provider == .apple ? .white : .gray900
    }

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if isPresented {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .semibold))

                    Text("최근 로그인")
                        .nekiFont(.caption12Medium)
                }
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
                .allowsHitTesting(false)
            }
        }
    }
}

private extension View {
    func recentLoginBadge(provider: ProviderType, isPresented: Bool) -> some View {
        modifier(RecentLoginBadgeModifier(provider: provider, isPresented: isPresented))
    }
}

#Preview {
    LoginView(store: .init(initialState: LoginFeature.State(), reducer: { LoginFeature() }))
}
