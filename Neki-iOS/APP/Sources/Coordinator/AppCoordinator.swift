//
//  AppCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct AppCoordinator {
    
    @ObservableState
    enum State {
        case splash(SplashFeature.State)
        case auth(LoginCoordinator.State)
        case mainTab(MainTabCoordinator.State)
    }
    
    enum Action {
        case splash(SplashFeature.Action)
        case auth(LoginCoordinator.Action)
        case mainTab(MainTabCoordinator.Action)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                
            // MARK: - Splash 화면에서의 이동
            case .splash(.delegate(.moveToAuth)):
                state = .auth(LoginCoordinator.State())
                return .none
                
            case let .splash(.delegate(.moveToMainTab(user))):
                state = .mainTab(.init(user: user))
                return .none
                
            // MARK: - Auth 화면에서의 이동
            // 없음 아직
                
            // MARK: - MainTab 화면에서의 이동
            case .mainTab(.delegate(.logout)):
                state = .auth(LoginCoordinator.State())
                return .none
                
            default:
                return .none
            }
        }
        .ifCaseLet(\.splash, action: \.splash) { SplashFeature() }
        .ifCaseLet(\.mainTab, action: \.mainTab) { MainTabCoordinator() }
        .ifCaseLet(\.auth, action: \.auth) { LoginCoordinator() }
    }
}
