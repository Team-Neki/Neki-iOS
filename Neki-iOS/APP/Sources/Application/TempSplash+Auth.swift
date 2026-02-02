//
//  TempSplash+Auth.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import os

// MARK: - 1. Splash Feature
@Reducer
struct SplashFeature {
    @ObservableState
    struct State: Equatable {}
    
    enum Action {
        // View Actions
        case onAppear
        case didTapGoAuthButton
        
        // Internal Actions
        case autoLoginResponse(Result<User, Error>)
        
        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case moveToAuth
            case moveToMainTab(User)
        }
    }
    
    @Dependency(\.authClient) private var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.autoLoginResponse(Result { try await authClient.autoLogin() }))
                }
                
            case .didTapGoAuthButton:
                return .send(.delegate(.moveToAuth))
                
            case let .autoLoginResponse(.success(user)):
                return .send(.delegate(.moveToMainTab(user)))
                
            case let .autoLoginResponse(.failure(error)):
                Logger.presentation.debug("자동 로그인 시도 후 실패: \(error)")
                return .send(.delegate(.moveToAuth))
                
            case .delegate:
                return .none
            }
        }
    }
}

struct SplashView: View {
    let store: StoreOf<SplashFeature>
    
    var body: some View {
        ZStack {
            Color.blue.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Splash View 💦")
                    .font(.largeTitle)
                
                Button("Auth 화면으로 이동") {
                    store.send(.didTapGoAuthButton)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
