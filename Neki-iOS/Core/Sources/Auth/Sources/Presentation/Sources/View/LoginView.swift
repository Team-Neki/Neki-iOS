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
            .recentLoginTooltip(isPresented: store.recentLoginProvider == .apple)
    }

    private var kakaoLoginButton: some View {
        Button {
            store.send(.kakaoLogin)
        } label: {
            Image(.imgKakaoLogin)
                .resizable()
                .scaledToFit()
        }
        .recentLoginTooltip(isPresented: store.recentLoginProvider == .kakao)
        .onOpenURL { store.send(.handleKakaoOpenURL($0)) }
    }
}


// MARK: - RecentLoginTooltip

private extension View {
    func recentLoginTooltip(isPresented: Bool) -> some View {
        overlay(alignment: .topTrailing) {
            if isPresented {
                RecentLoginTooltip()
                    .padding(.trailing, RecentLoginTooltip.Constants.buttonTrailingInset)
                    .offset(y: RecentLoginTooltip.Constants.buttonVerticalOffset)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct RecentLoginTooltip: View {
    enum Constants {
        static let bodySize: CGSize = .init(width: 82, height: 27)
        static let tailSize: CGSize = .init(width: 7.5, height: 6)
        static let iconSize: CGSize = .init(width: 12, height: 12)
        static let title: String = "최근 로그인"
        static let contentSpacing: CGFloat = 4
        static let contentHorizontalPadding: CGFloat = 8
        static let contentVerticalPadding: CGFloat = 6
        static let bodyCornerRadius: CGFloat = 6
        static let tailTrailingInset: CGFloat = 8
        static let tailTipRadius: CGFloat = 0.8
        static let buttonTrailingInset: CGFloat = 8
        static let buttonVerticalOffset: CGFloat = -(bodySize.height / 2)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: .zero) {
            HStack(spacing: Constants.contentSpacing) {
                Image(.iconClock)
                    .frame(width: Constants.iconSize.width, height: Constants.iconSize.height)

                Text(Constants.title)
                    .nekiFont(.caption12Medium)
                    .foregroundStyle(.white)
            }
            .padding(.vertical, Constants.contentVerticalPadding)
            .padding(.horizontal, Constants.contentHorizontalPadding)
            .background(.gray800, in: RoundedRectangle(cornerRadius: Constants.bodyCornerRadius))

            RecentLoginTooltipTail()
                .fill(.gray800)
                .frame(width: Constants.tailSize.width, height: Constants.tailSize.height)
                .padding(.trailing, Constants.tailTrailingInset * 2)
        }
        .accessibilityHidden(true)
    }
}

private struct RecentLoginTooltipTail: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let tipRadius = min(RecentLoginTooltip.Constants.tailTipRadius, rect.width / 2, rect.height)
        let tipShoulderY = rect.maxY - tipRadius

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + tipRadius, y: tipShoulderY))
        path.addQuadCurve(to: CGPoint(x: rect.midX - tipRadius, y: tipShoulderY), control: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    LoginView(store: .init(initialState: LoginFeature.State(), reducer: { LoginFeature() }))
}
