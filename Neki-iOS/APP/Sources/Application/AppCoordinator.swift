//
//  AppCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture
import UserNotifications

@Reducer
struct AppCoordinator {
    enum Constants {
        static let versionCheckInterval: TimeInterval = 60 *  60 * 24 // 1일
        static let requiredTermsAgreementPolicyVersion: String = "2026-06-push-notification"
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
        var pendingShareAppGroupID: String?
        var lastVersionCheckedTime: Date?
        var isSynchronizingPushNotification: Bool = false
        var shouldRetryPushNotificationSynchronization: Bool = false
        var hasSynchronizedPushNotification: Bool = false
        var lastSynchronizedPushAgreement: Bool?
        
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
        case onOpenURL(URL)
        
        // Internal Actions
        case splashSequenceCompleted(UserSessionStatus, AppVersionClient.VersionResult)
        case userSessionStatusChanged(UserSessionStatus)
        case scenePhaseChanged(ScenePhase)
        case backgroundVersionCheckResult(Result<AppVersionClient.VersionResult, Error>)
        case executePendingShareExtensionIfNeeded
        case didRegisterAPNSToken
        case checkPushNotificationAuthorization
        case checkPushNotificationAuthorizationResponse(Result<UNAuthorizationStatus, Error>)
        case requestPushNotificationAuthorization
        case requestPushNotificationAuthorizationResponse(Result<UNAuthorizationStatus, Error>)
        case synchronizePushNotification
        case synchronizePushNotificationResponse(Result<UNAuthorizationStatus, Error>)
        
        // Binding Actions
        case binding(BindingAction<State>)
        
        // Child Actions
        case route(Route.Action)
    }
    
    @Dependency(\.authClient) private var authClient
    @Dependency(\.appVersionClient) private var appVersionClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
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
                
            case let .onOpenURL(url):
                guard (url.scheme == "neki" || url.scheme == "neki-dev") && url.host == "shareExtension" else { return .none }
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let appGroupID = components.queryItems?.first(where: { $0.name == "appGroupID" })?.value
                else { return .none }
                state.pendingShareAppGroupID = appGroupID
                
                guard case .mainTab = state.route else { return .none }
                return .send(.executePendingShareExtensionIfNeeded)
                
            case let .scenePhaseChanged(phase):
                guard phase == .active else { return .none }
                let authorizationEffect: Effect<Action> = .send(.checkPushNotificationAuthorization)

                guard state.versionAlert != .updateNeeded else { return authorizationEffect }
                guard state.lastVersionCheckedTime.map({ now.timeIntervalSince($0) >= Constants.versionCheckInterval }) ?? true else { return authorizationEffect }

                let versionEffect: Effect<Action> = .run { send in
                    await send(.backgroundVersionCheckResult(
                        Result { try await appVersionClient.checkVersion() }
                    ))
                }
                return .merge(authorizationEffect, versionEffect)
                
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
                
                let userID: Int? = extractUserID(from: finalStatus)
                let configureEffect: Effect<Action> = .run { _ in analytics.configure(userID) }
                
                guard finalVersionResult.status != .mustUpdate else {
                    state.versionAlert = .updateNeeded
                    return .none
                }
                
                guard finalVersionResult.status != .optionalUpdate else {
                    state.versionAlert = .updateAvailable
                    state.pendingSessionStatus = finalStatus
                    return .none
                }
                
                return .merge(
                    configureEffect,
                    navigateToNextScreen(state: &state, sessionStatus: finalStatus)
                )
                
            case .executePendingShareExtensionIfNeeded:
                guard let appGroupID = state.pendingShareAppGroupID else { return .none }
                guard case .mainTab = state.route else { return .none }
                state.pendingShareAppGroupID = nil
                return .send(.route(.mainTab(.archive(.root(.addPhotoFromShareExtension(appGroupID: appGroupID))))))

            case .didRegisterAPNSToken:
                guard case .signedIn = state.userSessionStatus else { return .none }
                state.hasSynchronizedPushNotification = false
                guard state.isSynchronizingPushNotification == false else {
                    state.shouldRetryPushNotificationSynchronization = true
                    return .none
                }
                return .send(.synchronizePushNotification)
                
            case .didTapUpdateAlert:
                guard let appStoreURL = URL(string: "https://apps.apple.com/kr/app/id6757490609") else { return .none }
                return .run { _ in await openURL(appStoreURL) }
                
            case .didTapLaterAlert:
                state.versionAlert = nil
                guard let pendingSessionStatus = state.pendingSessionStatus else { return .none }
                state.pendingSessionStatus = nil
                return navigateToNextScreen(state: &state, sessionStatus: pendingSessionStatus)
                
            case let .userSessionStatusChanged(newStatus):
                if state.userSessionStatus != newStatus { state.$userSessionStatus.withLock { $0 = newStatus } }
                
                let userID: Int? = extractUserID(from: newStatus)
                let configureEffect: Effect<Action> = .run { _ in analytics.configure(userID) }
                
                if case .splash = state.route, state.versionAlert != nil { return configureEffect }
                
                let navigationEffect: Effect<Action>
                switch newStatus {
                case let .signedIn(user):
                    if case .mainTab = state.route {
                        navigationEffect = .none
                    } else {
                        state.route = .mainTab(.init(
                            shouldPresentMarketingConsentAlert: isMarketingConsentAlertEligible(for: user)
                        ))
                        navigationEffect = .none
                    }
                    
                case .signedOut, .expired:
                    state.hasSynchronizedPushNotification = false
                    state.shouldRetryPushNotificationSynchronization = false
                    state.lastSynchronizedPushAgreement = nil
                    state.route = .auth(.init())
                    if case .expired = newStatus { state.toastItem = .init("다시 로그인 해주세요.") }
                    navigationEffect = .none
                }
                
                return .merge(
                    configureEffect,
                    navigationEffect,
                    .send(.checkPushNotificationAuthorization)
                )
                
            case .route(.onboarding(.delegate(.didFinishOnboarding))):
                state.$hasSeenOnboarding.withLock { $0 = true }
                state.route = .auth(.init())
                return .none
                
            case let .route(.auth(.delegate(.moveToMainTab(
                user,
                shouldPresentMarketingConsentAlert,
                didCompleteTermsAgreement
            )))):
                if didCompleteTermsAgreement {
                    markRequiredTermsAgreementPolicyCompleted(for: user)
                }
                state.$userSessionStatus.withLock { $0 = .signedIn(user) }
                let configureEffect: Effect<Action> = .run { _ in analytics.configure(user.id) }
                return .merge(
                    configureEffect,
                    navigateToNextScreen(
                        state: &state,
                        sessionStatus: .signedIn(user),
                        shouldPresentMarketingConsentAlert: shouldPresentMarketingConsentAlert
                    ),
                    .send(.executePendingShareExtensionIfNeeded)
                )

            case let .route(.termsAgreement(.didFinishOnboarding(user))):
                markRequiredTermsAgreementPolicyCompleted(for: user)
                state.$userSessionStatus.withLock { $0 = .signedIn(user) }
                return navigateToNextScreen(
                    state: &state,
                    sessionStatus: .signedIn(user),
                    shouldPresentMarketingConsentAlert: user.marketingTermAgreed == false
                )

            case .route(.mainTab(.delegate(.pushNotificationAuthorizationResolved))):
                guard case .signedIn = state.userSessionStatus else { return .none }
                state.hasSynchronizedPushNotification = false
                guard state.isSynchronizingPushNotification == false else {
                    state.shouldRetryPushNotificationSynchronization = true
                    return .none
                }
                return .send(.synchronizePushNotification)

            case .checkPushNotificationAuthorization:
                guard case .signedIn = state.userSessionStatus,
                      case .mainTab = state.route
                else { return .none }
                return .run { send in
                    await send(.checkPushNotificationAuthorizationResponse( Result { try await pushNotificationClient.checkAuthorizationStatus() } ))
                }

            case let .checkPushNotificationAuthorizationResponse(.success(status)):
                if status == .notDetermined {
                    guard case let .signedIn(user) = state.userSessionStatus,
                          user.marketingTermAgreed
                    else { return .none }
                    return .send(.requestPushNotificationAuthorization)
                }

                let currentAgreement = status.isPushNotificationAgreed
                guard state.lastSynchronizedPushAgreement != currentAgreement else { return .none }
                state.hasSynchronizedPushNotification = false
                return .send(.synchronizePushNotification)

            case .checkPushNotificationAuthorizationResponse(.failure):
                return .none

            case .requestPushNotificationAuthorization:
                return .run { send in
                    await send(.requestPushNotificationAuthorizationResponse(Result {
                        _ = try await pushNotificationClient.requestAuthorization()
                        return try await pushNotificationClient.checkAuthorizationStatus()
                    }))
                }

            case .requestPushNotificationAuthorizationResponse(.success):
                state.hasSynchronizedPushNotification = false
                guard state.isSynchronizingPushNotification == false else {
                    state.shouldRetryPushNotificationSynchronization = true
                    return .none
                }
                return .send(.synchronizePushNotification)

            case .requestPushNotificationAuthorizationResponse(.failure):
                return .none

            case .synchronizePushNotification:
                guard case .signedIn = state.userSessionStatus else { return .none }
                guard state.isSynchronizingPushNotification == false,
                      state.hasSynchronizedPushNotification == false
                else { return .none }
                state.isSynchronizingPushNotification = true
                return .run { send in
                    await send(.synchronizePushNotificationResponse( Result { try await pushNotificationClient.synchronizeDeviceToken() } ))
                }

            case let .synchronizePushNotificationResponse(.success(status)):
                state.isSynchronizingPushNotification = false
                state.shouldRetryPushNotificationSynchronization = false
                state.hasSynchronizedPushNotification = true
                state.lastSynchronizedPushAgreement = status.isPushNotificationAgreed
                return .none

            case .synchronizePushNotificationResponse(.failure):
                state.isSynchronizingPushNotification = false
                guard state.shouldRetryPushNotificationSynchronization else { return .none }
                state.shouldRetryPushNotificationSynchronization = false
                return .send(.synchronizePushNotification)
                
            case .route(.mainTab(.delegate(.signedOut))), .route(.mainTab(.delegate(.withdraw))):
                state.hasSynchronizedPushNotification = false
                state.shouldRetryPushNotificationSynchronization = false
                state.lastSynchronizedPushAgreement = nil
                state.$userSessionStatus.withLock { $0 = .signedOut }
                if case .route(.mainTab(.delegate(.withdraw))) = action {
                    state.initializeUserDefaults()
                }
                state.route = .auth(.init())
                return .run { _ in analytics.configure(nil) }
                
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
}

private extension UNAuthorizationStatus {
    var isPushNotificationAgreed: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}


// MARK: - AppCoordinator + Helpers

private extension AppCoordinator {
    func navigateToNextScreen(
        state: inout State,
        sessionStatus: UserSessionStatus,
        shouldPresentMarketingConsentAlert: Bool = false
    ) -> Effect<Action> {
        switch sessionStatus {
        case let .signedIn(user):
            guard shouldPresentRequiredTermsAgreement(for: user) == false else {
                state.route = .termsAgreement(.init())
                return .none
            }

            state.route = .mainTab(.init(
                shouldPresentMarketingConsentAlert: shouldPresentMarketingConsentAlert
                    || isMarketingConsentAlertEligible(for: user)
            ))
            return .merge(
                .send(.checkPushNotificationAuthorization),
                .send(.executePendingShareExtensionIfNeeded)
            )
            
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
    
    func extractUserID(from status: UserSessionStatus) -> Int? {
        guard case let .signedIn(user) = status else { return nil }
        return user.id
    }

    func isMarketingConsentAlertEligible(for user: User) -> Bool {
        guard user.marketingTermAgreed == false else { return false }
        let key = AppStorageKey.marketingConsentAlertPresentationCount(userID: user.id)
        return UserDefaults.standard.integer(forKey: key) < 2
    }

    func shouldPresentRequiredTermsAgreement(for user: User) -> Bool {
        guard user.allRequiredTermsAgreed else { return false }
        let key = AppStorageKey.requiredTermsAgreementPolicyVersion(userID: user.id)
        return UserDefaults.standard.string(forKey: key) != Constants.requiredTermsAgreementPolicyVersion
    }

    func markRequiredTermsAgreementPolicyCompleted(for user: User) {
        let key = AppStorageKey.requiredTermsAgreementPolicyVersion(userID: user.id)
        UserDefaults.standard.set(Constants.requiredTermsAgreementPolicyVersion, forKey: key)
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
            case termsAgreement(TermsAgreementFeature.State)
            case mainTab(MainTabCoordinator.State)
        }
        
        enum Action {
            case splash
            case onboarding(OnboardingCoordinator.Action)
            case auth(LoginCoordinator.Action)
            case termsAgreement(TermsAgreementFeature.Action)
            case mainTab(MainTabCoordinator.Action)
        }
        
        var body: some ReducerOf<Self> {
            Reduce { (state: inout State, action: Action) -> Effect<Action> in
                return .none
            }
            .ifCaseLet(\.onboarding, action: \.onboarding) { OnboardingCoordinator() }
            .ifCaseLet(\.auth, action: \.auth) { LoginCoordinator() }
            .ifCaseLet(\.termsAgreement, action: \.termsAgreement) { TermsAgreementFeature() }
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
