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
    enum Constants {
        static let versionCheckInterval: TimeInterval = 60 *  60 * 24 // 1일
    }
    
    @ObservableState
    struct State {
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut
        
        // 온보딩(앱 최초 실행시) 여부
        @Shared(.appStorage("hasSeenOnboarding")) var hasSeenOnboarding: Bool = false
        
        var toastItem: NekiToastItem?
        var route: Route.State
        var versionAlert: VersionUpdateAlertType?
        var isAlertPresented: Bool {
            get { versionAlert != nil }
            set {
                guard newValue == false else { return }
                guard versionAlert != .updateNeeded else { return }
                versionAlert = nil
            }
        }
        var pendingSessionStatus: UserSessionStatus?
        var lastVersionCheckedTime: Date?
        
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
        case didTapUpdateAlert
        case didTapLaterAlert
        
        // Internal Actions
        case splashSequenceCompleted(UserSessionStatus, AppVersionClient.VersionResult)
        case userSessionStatusChanged(UserSessionStatus)
        case scenePhaseChanged(ScenePhase)
        case backgroundVersionCheckResult(Result<AppVersionClient.VersionResult, Error>)
        
        // Binding Actions
        case binding(BindingAction<State>)
        
        // Child Actions
        case route(Route.Action)
    }
    
    @Dependency(\.authClient) private var authClient
    @Dependency(\.appVersionClient) private var appVersionClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.openURL) private var openURL
    @Dependency(\.date.now) private var now
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.route, action: \.route) { Route() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppLaunched:
                state.lastVersionCheckedTime = now
                
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
                    
                    async let versionResult: AppVersionClient.VersionResult = {
                        do {
                            return try await appVersionClient.checkVersion()
                        } catch {
                            // TODO: 네트워크 에러 등으로 버전 정보를 확보하지 못했을 때는 최신 상태로 간주하여 앱 진입 할 수 있도록 함, 추후 개선 필요
                            return (.init(value: "0.0.0"), .init(value: "0.0.0"), .upToDate)
                        }
                    }()
                    
                    let (_, finalStatus, finalVersionResult) = try await (timer, nextStatus, versionResult)
                    
                    await send(.splashSequenceCompleted(finalStatus, finalVersionResult))
                }
                
            case let .scenePhaseChanged(phase):
                guard phase == .active else { return .none }
                if state.versionAlert == .updateNeeded { return .none }
                if let lastTime = state.lastVersionCheckedTime, now.timeIntervalSince(lastTime) < Constants.versionCheckInterval { return .none }
                return .run { send in
                    do {
                        let result = try await appVersionClient.checkVersion()
                        await send(.backgroundVersionCheckResult(.success(result)))
                    } catch {
                        await send(.backgroundVersionCheckResult(.failure(error)))
                    }
                }
                
            case let .backgroundVersionCheckResult(result):
                guard case let .success(version) = result else { return .none }
                state.lastVersionCheckedTime = now
                
                switch version.status {
                case .mustUpdate:
                    state.versionAlert = .updateNeeded
                    return .none
                    
                case .optionalUpdate:
                    guard state.versionAlert == nil else { return .none }
                    state.versionAlert = .updateAvailable
                    return .none
                    
                case .upToDate:
                    return .none
                }
                
            case let .splashSequenceCompleted(finalStatus, finalVersionResult):
                state.$userSessionStatus.withLock { $0 = finalStatus }
                
                guard finalVersionResult.status != .mustUpdate else {
                    state.versionAlert = .updateNeeded
                    return .none
                }
                
                guard finalVersionResult.status != .optionalUpdate else {
                    state.versionAlert = .updateAvailable
                    state.pendingSessionStatus = finalStatus
                    return .none
                }
                
                return navigateToNextScreen(state: &state, sessionStatus: finalStatus)
                
            case .didTapUpdateAlert:
                // TODO: 앱스토어 URL 필요
                return .run { _ in
                    let appStoreURL = URL(string: "https://itunes.apple.com/kr/app/neki")!
                    await openURL(appStoreURL)
                }
                
            case .didTapLaterAlert:
                state.versionAlert = nil
                guard let pendingSessionStatus = state.pendingSessionStatus else { return .none }
                state.pendingSessionStatus = nil
                return navigateToNextScreen(state: &state, sessionStatus: pendingSessionStatus)
                
            case let .userSessionStatusChanged(newStatus):
                if state.userSessionStatus != newStatus { state.$userSessionStatus.withLock { $0 = newStatus } }
                
                if case .splash = state.route, state.versionAlert != nil { return .none }
                
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
                state.route = .auth(.init())
                return .send(.onAppLaunched)
                
            case .route(.mainTab(.delegate(.withdraw))):
                state.$userSessionStatus.withLock { $0 = .signedOut }
                state.initializeUserDefaults()
                state.route = .auth(.init())
                return .send(.onAppLaunched)
                
            case let .route(.mainTab(.delegate(.profileUpdated(user)))):
                state.$userSessionStatus.withLock { $0 = .signedIn(user) }
                return .none
                
            case .binding(\.isAlertPresented):
                guard state.isAlertPresented == false else { return .none }
                guard let pendingSessionStatus = state.pendingSessionStatus else { return .none }
                state.pendingSessionStatus = nil
                return navigateToNextScreen(state: &state, sessionStatus: pendingSessionStatus)
                
            default:
                return .none
            }
        }
    }
    
    private func navigateToNextScreen(state: inout State, sessionStatus: UserSessionStatus) -> Effect<Action> {
        switch sessionStatus {
        case .signedIn(let user):
            state.route = .mainTab(.init(user: user))
            return .none
            
        case .signedOut, .expired:
            if state.hasSeenOnboarding {
                state.route = .auth(.init())
                if case .expired = sessionStatus { state.toastItem = .init("다시 로그인 해주세요.") }
            } else {
                state.route = .onboarding(.init())
            }
            return .none
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
        UserDefaults.standard.removeObject(forKey: "showTooltip")       // 아카이빙 홈 툴팁
        UserDefaults.standard.removeObject(forKey: "isTutorialPresented")   // 랜덤포즈 튜토리얼
    }
}


// MARK: - Nested Types

extension AppCoordinator {
    enum VersionUpdateAlertType {
        case updateNeeded // 필수 업데이트 안내
        case updateAvailable // 새로운 버전 안내
        
        var style: NekiAlertStyle {
            switch self {
            case .updateNeeded: .plain
            case .updateAvailable: .cancelable
            }
        }
        
        var title: String {
            switch self {
            case .updateNeeded: return "필수 업데이트 안내"
            case .updateAvailable: return "새로운 버전 업데이트"
            }
        }
        
        var subtitle: String {
            switch self {
            case .updateNeeded: return "더 안정적인 서비스 이용을 위해\n필수 업데이트가 필요해요"
            case .updateAvailable: return "새로운 기능이 추가되었어요!\n더 나은 이용을 위해 업데이트 해보세요"
            }
        }
        
        var confirmText: String {
            switch self {
            case .updateNeeded: return "업데이트 하러 가기"
            case .updateAvailable: return "업데이트"
            }
        }
        
        var cancelText: String? {
            switch self {
            case .updateNeeded: return nil
            case .updateAvailable: return "다음에 할래요"
            }
        }
    }
}
