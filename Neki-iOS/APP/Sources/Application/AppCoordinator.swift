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
        
        // 온보딩(앱 최초 실행시) 여부
        @Shared(.appStorage("hasSeenOnboarding")) var hasSeenOnboarding: Bool = false
        
        var toastItem: NekiToastItem?
        
        var route: Route.State
        
        init() {
            //            var initialStatus: UserSessionStatus
            //            guard let data = UserDefaults.standard.data(forKey: AppStorageKey.userSessionStatus),
            //                  let status = try? JSONDecoder().decode(UserSessionStatus.self, from: data)
            //            else { route = .auth(.init()); return }
            //            initialStatus = status
            //            switch initialStatus {
            //            case let .signedIn(user): self.route = .mainTab(.init(user: user))
            //            case .signedOut, .expired: self.route = .auth(.init())
            //            }
            if let data = UserDefaults.standard.data(forKey: AppStorageKey.userSessionStatus),
               let status = try? JSONDecoder().decode(UserSessionStatus.self, from: data),
               case let .signedIn(user) = status {
                self.route = .mainTab(.init(user: user))
                return
            }
            
            let seenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            
            if seenOnboarding {
                self.route = .auth(.init())
            } else {
                self.route = .onboarding(.init())
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
                if state.userSessionStatus != newStatus { state.$userSessionStatus.withLock { $0 = newStatus } }
                switch newStatus {
                case let .signedIn(user):
                    if case var .mainTab(mainTabState) = state.route {
                        mainTabState.user = user
                        state.route = .mainTab(.init(user: user))
                        return .none
                    }
                    state.route = .mainTab(.init(user: user))
                    return .none
                    
                case .signedOut, .expired:
                    state.route = .auth(.init())
                    
                    guard case .expired = newStatus else { return .none }
                    state.toastItem = .init("다시 로그인 해주세요.")
                    return .none
                }
                
            case .route(.onboarding(.delegate(.didFinishOnboarding))):
                state.$hasSeenOnboarding.withLock { $0 = true }
                state.route = .auth(.init())
                return .none
                
            case let .route(.auth(.delegate(.moveToMainTab(user)))):
                state.$userSessionStatus.withLock { $0 = .signedIn(user) }
                state.route = .mainTab(.init(user: user))
                return .none
                
            case .route(.mainTab(.delegate(.signedOut))):
                state.$userSessionStatus.withLock { $0 = .signedOut }
                state.route = .auth(.init())
                return .none
                
            case let .route(.mainTab(.delegate(.profileUpdated(user)))):
                state.$userSessionStatus.withLock { $0 = .signedIn(user) }
                return .none
                
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
            case onboarding(OnboardingCoordinator.State)
            case auth(LoginCoordinator.State)
            case mainTab(MainTabCoordinator.State)
        }
        
        enum Action {
            case onboarding(OnboardingCoordinator.Action)
            case auth(LoginCoordinator.Action)
            case mainTab(MainTabCoordinator.Action)
        }
        
        var body: some ReducerOf<Self> {
            Reduce { (state: inout State, action: Action) -> Effect<Action> in
                return .none
            }
            .ifCaseLet(\.onboarding, action: \.onboarding) { OnboardingCoordinator() }
            .ifCaseLet(\.auth, action: \.auth) { LoginCoordinator() }
            .ifCaseLet(\.mainTab, action: \.mainTab) { MainTabCoordinator() }
        }
    }
}
