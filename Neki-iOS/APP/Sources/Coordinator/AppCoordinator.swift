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
    struct State {
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut
        var toastItem: NekiToastItem?
        
        var route: Route.State
        
        init() {
            var initialStatus: UserSessionStatus
            guard let data = UserDefaults.standard.data(forKey: AppStorageKey.userSessionStatus),
                  let status = try? JSONDecoder().decode(UserSessionStatus.self, from: data)
            else { route = .auth(.init()); return }
            initialStatus = status
            switch initialStatus {
            case let .signedIn(user): self.route = .mainTab(.init(user: user))
            case .signedOut, .expired: self.route = .auth(.init())
            }
        }
    }
    
    enum Action: BindableAction {
        // View Actions
        case onAppLaunched
        
        case userSessionStatusChanged(UserSessionStatus)
        
        // Binding Actions
        case binding(BindingAction<State>)
        
        // Child Actions
        case route(Route.Action)
    }
    
    @Dependency(\.authClient) private var authClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.route, action: \.route) { Route() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppLaunched:
                return .run { [status = state.userSessionStatus] send in
                    guard case .signedIn = status else { return }
                    do {
                        let user = try await authClient.autoLogin()
                        await send(.userSessionStatusChanged(.signedIn(user)))
                    } catch {
                        await send(.userSessionStatusChanged(.signedOut))
                    }
                }
                
            case let .userSessionStatusChanged(newStatus):
                switch newStatus {
                case let .signedIn(user):
                    if case .mainTab = state.route { return .none }
                    state.route = .mainTab(.init(user: user))
                    return .none
                    
                case .signedOut, .expired:
                    state.route = .auth(.init())
                    
                    guard case .expired = newStatus else { return .none }
                    state.toastItem = .init("다시 로그인 해주세요.")
                    return .none
                }
                
            default:
                return .none
            }
        }
    }
}

extension AppCoordinator {
    @Reducer
    struct Route {
        @ObservableState
        enum State {
            case auth(LoginCoordinator.State)
            case mainTab(MainTabCoordinator.State)
        }
        
        enum Action {
            case auth(LoginCoordinator.Action)
            case mainTab(MainTabCoordinator.Action)
        }
        
        var body: some ReducerOf<Self> {
            Reduce { (state: inout State, action: Action) -> Effect<Action> in
                return .none
            }
            .ifCaseLet(\.auth, action: \.auth) { LoginCoordinator() }
            .ifCaseLet(\.mainTab, action: \.mainTab) { MainTabCoordinator() }
        }
    }
}
