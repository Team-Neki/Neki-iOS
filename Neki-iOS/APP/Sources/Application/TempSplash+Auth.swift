//
//  TempSplash+Auth.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import Foundation
import SwiftUI
import ComposableArchitecture

// MARK: - 1. Splash Feature
@Reducer
struct SplashFeature {
    @ObservableState
    struct State: Equatable {}
    
    enum Action {
        case didTapGoAuthButton
        case delegate(Delegate)
        enum Delegate { case moveToAuth }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .didTapGoAuthButton:
                return .send(.delegate(.moveToAuth))
            default:
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

// MARK: - 2. Auth Coordinator
@Reducer
struct AuthCoordinator {
    @ObservableState
    struct State: Equatable {}
    
    enum Action {
        case didTapGoSplashButton
        case didTapLoginButton
        
        case delegate(Delegate)
        enum Delegate {
            case moveToSplash
            case moveToMainTab
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .didTapGoSplashButton:
                return .send(.delegate(.moveToSplash))
                
            case .didTapLoginButton:
                return .send(.delegate(.moveToMainTab))
                
            default:
                return .none
            }
        }
    }
}

struct AuthCoordinatorView: View {
    let store: StoreOf<AuthCoordinator>
    
    var body: some View {
        ZStack {
            Color.yellow.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Auth View 🔒")
                    .font(.largeTitle)
                
                Button("Splash로 돌아가기") {
                    store.send(.didTapGoSplashButton)
                }
                .tint(.gray)
                .buttonStyle(.borderedProminent)
                
                Button("로그인 완료 (메인으로)") {
                    store.send(.didTapLoginButton)
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
