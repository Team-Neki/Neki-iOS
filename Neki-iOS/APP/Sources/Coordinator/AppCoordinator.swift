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
        case auth(AuthCoordinator.State)
        case mainTab(MainTabCoordinator.State)
    }
    
    enum Action {
        case splash(SplashFeature.Action)
        case auth(AuthCoordinator.Action)
        case mainTab(MainTabCoordinator.Action)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            // MARK: - Splash 화면에서의 이동
            case .splash(.delegate(.moveToAuth)):
                state = .auth(AuthCoordinator.State())
                return .none
                
            // MARK: - Auth 화면에서의 이동
            case .auth(.delegate(.moveToSplash)):
                state = .splash(SplashFeature.State())
                return .none
                
            case .auth(.delegate(.moveToMainTab)):
                state = .mainTab(MainTabCoordinator.State())
                return .none
                
            // MARK: - MainTab 화면에서의 이동
            case .mainTab(.delegate(.logout)):
                state = .auth(AuthCoordinator.State())
                return .none
                
            default:
                return .none
            }
        }
        .ifCaseLet(\.splash, action: \.splash) { SplashFeature() }
        .ifCaseLet(\.auth, action: \.auth) { AuthCoordinator() }
        .ifCaseLet(\.mainTab, action: \.mainTab) { MainTabCoordinator() }
    }
}
