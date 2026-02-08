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
            self.route = .splash
            
            // QA처럼 최초 1회성 뷰들을 매번 보여줘야 할 때 사용
//#if DEBUG
//            initializeUserDefaults()
//#endif
        }
    }
    
    enum Action: BindableAction {
        // View Actions
        case onAppLaunched
        
        case splashSequenceCompleted(UserSessionStatus)
        
        case userSessionStatusChanged(UserSessionStatus)
        
        // Binding Actions
        case binding(BindingAction<State>)
        
        // Child Actions
        case route(Route.Action)
    }
    
    @Dependency(\.authClient) private var authClient
    @Dependency(\.continuousClock) var clock
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.route, action: \.route) { Route() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppLaunched:
                return .run { [currentStatus = state.userSessionStatus] send in
                    async let timer: Void = clock.sleep(for: .milliseconds(1500))
                    
                    async let nextStatus: UserSessionStatus = {
                        guard case .signedIn = currentStatus else { return currentStatus }
                        
                        do {
                            let user = try await authClient.autoLogin()
                            return .signedIn(user)
                        } catch {
                            return .signedOut
                        }
                    }()
                    
                    let (_, finalStatus) = try await (timer, nextStatus)
                    
                    await send(.splashSequenceCompleted(finalStatus))
                }
                
            case let .splashSequenceCompleted(finalStatus):
                state.$userSessionStatus.withLock { $0 = finalStatus }
                
                switch finalStatus {
                case let .signedIn(user):
                    state.route = .mainTab(.init(user: user))
                    
                case .signedOut, .expired:
                    if state.hasSeenOnboarding {
                        state.route = .auth(.init())
                        
                        if case .expired = finalStatus {
                            state.toastItem = .init("다시 로그인 해주세요.")
                        }
                    } else {
                        state.route = .onboarding(.init())
                    }
                }
                return .none
                
            case let .userSessionStatusChanged(newStatus):
                if state.userSessionStatus != newStatus { state.$userSessionStatus.withLock { $0 = newStatus } }
                
                if case .splash = state.route { return .none }
                
                switch newStatus {
                case let .signedIn(user):
                    if case var .mainTab(mainTabState) = state.route {
                        mainTabState.user = user
                        state.route = .mainTab(.init(user: user))
                        return .none
                    }
                    state.route = .mainTab(.init(user: user))
                    return .none
                    
                case .signedOut:
                    state.route = .auth(.init())
                    guard case .expired = newStatus else { return .none }
                    state.toastItem = .init("다시 로그인 해주세요.")
                    return .none
                    
                case .expired:
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
                state.route = .splash
                return .send(.onAppLaunched)
                
            case .route(.mainTab(.delegate(.withdraw))):
                state.$userSessionStatus.withLock { $0 = .signedOut }
                state.initializeUserDefaults()
                state.route = .splash
                return .send(.onAppLaunched)
                
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
            case splash
            case onboarding(OnboardingCoordinator.State)
            case auth(LoginCoordinator.State)
            case mainTab(MainTabCoordinator.State)
        }
        
        enum Action {
            case splash
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


// MARK: - UserDefault로 지닌 값들 초기화 함수

private extension AppCoordinator.State {
    func initializeUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding") // 최초 온보딩
        UserDefaults.standard.removeObject(forKey: "OnboardingNeeded")  // 약관동의
        UserDefaults.standard.removeObject(forKey: "showTooltip")       // 아카이빙 홈 툴팁
        UserDefaults.standard.removeObject(forKey: "isTutorialPresented")   // 랜덤포즈 튜토리얼
    }
}
