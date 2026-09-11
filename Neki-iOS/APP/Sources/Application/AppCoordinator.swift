//
//  AppCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture
import os
import UserNotifications

@Reducer
struct AppCoordinator {
    enum Constants {
        static let versionCheckInterval: TimeInterval = 60 *  60 * 24 // 1일
        static let marketingConsentAlertRevisitInterval: TimeInterval = 60 * 60 * 24 * 7 // 7일
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
        var pendingAnalyticsSessionStatus: UserSessionStatus?
        var sessionObservationID: UUID?
        var pendingRouteRequest: AppRouteRequest?
        var lastVersionCheckedTime: Date?
        var isSynchronizingPushNotification: Bool = false
        var shouldRetryPushNotificationSynchronization: Bool = false
        var hasSynchronizedPushNotification: Bool = false
        var lastSynchronizedPushAgreement: Bool?
        var isAPNSTokenRegistered: Bool = false
        var pushNotificationEvent = PushNotificationEventFeature.State()
        
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
        case sessionExpirationReceived(UserSessionStatus, observationID: UUID)
        case analyticsSessionConfigured(UserSessionStatus, shouldPresentMarketingConsentAlert: Bool)
        case scenePhaseChanged(ScenePhase)
        case backgroundVersionCheckResult(Result<AppVersionClient.VersionResult, Error>)
        case executePendingRouteIfNeeded
        case checkPushNotificationAuthorization
        case checkPushNotificationAuthorizationResponse(Result<UNAuthorizationStatus, Error>)
        case synchronizePushNotification
        case synchronizePushNotificationResponse(Result<UNAuthorizationStatus, Error>)
        case pushNotificationEvent(PushNotificationEventFeature.Action)
        
        // Binding Actions
        case binding(BindingAction<State>)
        
        // Child Actions
        case route(Route.Action)
    }

    private enum CancelID: Hashable {
        case sessionExpirationObservation
        case analyticsSessionConfiguration
        case pushNotificationAuthorizationCheck
    }
    
    @Dependency(\.authClient) private var authClient
    @Dependency(\.appVersionClient) private var appVersionClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.openURL) private var openURL
    @Dependency(\.date.now) private var now
    @Dependency(\.uuid) private var uuid
    private let appRouter = AppRouter()
    
    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.pushNotificationEvent, action: \.pushNotificationEvent) { PushNotificationEventFeature() }
        
        Scope(state: \.route, action: \.route) { Route() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppLaunched:
                state.lastVersionCheckedTime = now
                
                let launchEffect: Effect<Action> = .run { [currentStatus = state.userSessionStatus] send in
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
                return .merge(
                    observeSessionExpiration(state: &state),
                    .send(.pushNotificationEvent(.task)),
                    launchEffect
                )
                
            case let .onOpenURL(url):
                return appRouter.handleOpenURL(state: &state, url: url)
                
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
                let finalStatus: UserSessionStatus = state.userSessionStatus == .expired ? .expired : finalStatus
                state.$userSessionStatus.withLock { $0 = finalStatus }
                
                guard finalVersionResult.status != .mustUpdate else {
                    state.versionAlert = .updateNeeded
                    return setAnalyticsSessionEffect(state: &state, for: finalStatus)
                }
                
                guard finalVersionResult.status != .optionalUpdate else {
                    state.versionAlert = .updateAvailable
                    state.pendingSessionStatus = finalStatus
                    return setAnalyticsSessionEffect(state: &state, for: finalStatus)
                }
                
                return configureAnalyticsSession(
                    state: &state,
                    status: finalStatus
                )
                
            case .executePendingRouteIfNeeded:
                return appRouter.executePendingRouteIfNeeded(state: &state)

            case .pushNotificationEvent(.delegate(.didRegisterAPNSToken)):
                state.isAPNSTokenRegistered = true
                return synchronizePushNotificationIfReady(&state)

            case .pushNotificationEvent(.delegate(.didReceiveFCMRegistrationToken)):
                guard isAPNSTokenRegistered(&state) else { return .none }
                return synchronizePushNotificationIfReady(&state)
                
            case .didTapUpdateAlert:
                guard let appStoreURL = URL(string: "https://apps.apple.com/kr/app/id6757490609") else { return .none }
                return .run { _ in await openURL(appStoreURL) }
                
            case .didTapLaterAlert:
                state.versionAlert = nil
                guard let pendingSessionStatus = state.pendingSessionStatus else { return .none }
                state.pendingSessionStatus = nil
                return configureAnalyticsSession(
                    state: &state,
                    status: pendingSessionStatus
                )
                
            case let .sessionExpirationReceived(status, observationID):
                guard state.sessionObservationID == observationID,
                      case .signedIn = state.userSessionStatus,
                      status == .expired else { return .none }
                return handleSessionStatusChanged(state: &state, status: status)

            case let .userSessionStatusChanged(newStatus):
                return handleSessionStatusChanged(state: &state, status: newStatus)

            case let .analyticsSessionConfigured(status, shouldPresentMarketingConsentAlert):
                guard state.pendingAnalyticsSessionStatus == status else { return .none }
                state.pendingAnalyticsSessionStatus = nil
                return navigateToNextScreen(
                    state: &state,
                    sessionStatus: status,
                    shouldPresentMarketingConsentAlert: shouldPresentMarketingConsentAlert
                )
                
            case .route(.onboarding(.delegate(.didFinishOnboarding))):
                state.$hasSeenOnboarding.withLock { $0 = true }
                state.route = .auth(.init())
                return .none

            case let .route(.auth(.delegate(.moveToMainTab(
                user,
                shouldPresentMarketingConsentAlert,
                didCompleteTermsAgreement,
                marketingConsentStatus
            )))):
                if didCompleteTermsAgreement {
                    if let marketingConsentStatus {
                        markMarketingConsentManaged(
                            for: user,
                            status: marketingConsentStatus
                        )
                    }
                }
                let signedInStatus = UserSessionStatus.signedIn(user)
                state.pendingAnalyticsSessionStatus = signedInStatus
                state.$userSessionStatus.withLock { $0 = signedInStatus }
                return .merge(
                    observeSessionExpiration(state: &state),
                    configureAnalyticsSession(
                        state: &state,
                        status: signedInStatus,
                        shouldPresentMarketingConsentAlert: shouldPresentMarketingConsentAlert
                    )
                )

            case let .route(.termsAgreement(.didFinishOnboarding(user, marketingConsentStatus))):
                if let marketingConsentStatus {
                    markMarketingConsentManaged(
                        for: user,
                        status: marketingConsentStatus
                    )
                }
                let signedInStatus = UserSessionStatus.signedIn(user)
                state.pendingAnalyticsSessionStatus = signedInStatus
                state.$userSessionStatus.withLock { $0 = signedInStatus }
                return configureAnalyticsSession(
                    state: &state,
                    status: signedInStatus,
                    shouldPresentMarketingConsentAlert: false
                )

            case .checkPushNotificationAuthorization:
                guard case .signedIn = state.userSessionStatus, case .mainTab = state.route else { return .none }
                _ = isAPNSTokenRegistered(&state)
                return .run { send in
                    do {
                        let status = try await pushNotificationClient.checkAuthorizationStatus()
                        try Task.checkCancellation()
                        await send(.checkPushNotificationAuthorizationResponse(.success(status)))
                    } catch is CancellationError { return } catch {
                        await send(.checkPushNotificationAuthorizationResponse(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.pushNotificationAuthorizationCheck, cancelInFlight: true)

            case let .checkPushNotificationAuthorizationResponse(.success(status)):
                let currentAgreement = status.isPushNotificationAgreed
                guard state.hasSynchronizedPushNotification == false ||
                      state.lastSynchronizedPushAgreement != currentAgreement
                else { return .none }
                return synchronizePushNotificationIfReady(&state)

            case let .checkPushNotificationAuthorizationResponse(.failure(error)):
                Logger.presentation.error("Push notification authorization check failed: \(error)")
                return synchronizePushNotificationIfReady(&state)

            case .synchronizePushNotification:
                guard case .signedIn = state.userSessionStatus else { return .none }
                guard isAPNSTokenRegistered(&state) else { return .none }
                guard state.isSynchronizingPushNotification == false,
                      state.hasSynchronizedPushNotification == false
                else { return .none }
                state.isSynchronizingPushNotification = true
                return .run { send in
                    await send(.synchronizePushNotificationResponse( Result { try await pushNotificationClient.synchronizeDeviceToken() } ))
                }

            case let .synchronizePushNotificationResponse(.success(status)):
                state.isSynchronizingPushNotification = false
                let shouldRetry = state.shouldRetryPushNotificationSynchronization
                state.shouldRetryPushNotificationSynchronization = false
                state.hasSynchronizedPushNotification = true
                state.lastSynchronizedPushAgreement = status.isPushNotificationAgreed
                Logger.presentation.debug("Push notification synchronization succeeded")
                guard shouldRetry else { return .none }
                state.hasSynchronizedPushNotification = false
                return .send(.synchronizePushNotification)

            case let .synchronizePushNotificationResponse(.failure(error)):
                Logger.presentation.error("Push notification synchronization failed: \(error)")
                state.isSynchronizingPushNotification = false
                guard state.shouldRetryPushNotificationSynchronization else { return .none }
                state.shouldRetryPushNotificationSynchronization = false
                return .send(.synchronizePushNotification)

            case .route(.mainTab(.delegate(.signedOut))), .route(.mainTab(.delegate(.withdraw))):
                state.hasSynchronizedPushNotification = false
                state.shouldRetryPushNotificationSynchronization = false
                state.lastSynchronizedPushAgreement = nil
                if case .route(.mainTab(.delegate(.withdraw))) = action {
                    state.initializeUserDefaults()
                }
                return .send(.userSessionStatusChanged(.signedOut))
                
            case .binding(\.isAlertPresented):
                guard state.isAlertPresented == false else { return .none }
                guard let pendingSessionStatus = state.pendingSessionStatus else { return .none }
                state.pendingSessionStatus = nil
                return configureAnalyticsSession(
                    state: &state,
                    status: pendingSessionStatus
                )
                
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
    func observeSessionExpiration(state: inout State) -> Effect<Action> {
        let observationID = uuid()
        state.sessionObservationID = observationID
        return .run { send in
            let statuses = try await authClient.observeSessionExpiration()
            for await status in statuses {
                guard Task.isCancelled == false else { return }
                await send(.sessionExpirationReceived(status, observationID: observationID))
            }
        }
        .cancellable(id: CancelID.sessionExpirationObservation, cancelInFlight: true)
    }

    func handleSessionStatusChanged(state: inout State, status: UserSessionStatus) -> Effect<Action> {
        if state.userSessionStatus != status { state.$userSessionStatus.withLock { $0 = status } }
        if status == .expired {
            if state.pendingSessionStatus != nil { state.pendingSessionStatus = .expired }
            state.pendingRouteRequest = nil
        }
        guard state.pendingAnalyticsSessionStatus != status else { return .none }
        if case .splash = state.route {
            guard state.versionAlert != nil else { return .none }
            return setAnalyticsSessionEffect(state: &state, for: status)
        }
        switch status {
        case .signedIn:
            guard case .mainTab = state.route else { return configureAnalyticsSession(state: &state, status: status) }
            return setAnalyticsSessionEffect(state: &state, for: status)
        case .signedOut, .expired:
            state.hasSynchronizedPushNotification = false
            state.shouldRetryPushNotificationSynchronization = false
            state.lastSynchronizedPushAgreement = nil
            return configureAnalyticsSession(state: &state, status: status)
        }
    }

    func configureAnalyticsSession(
        state: inout State,
        status: UserSessionStatus,
        shouldPresentMarketingConsentAlert: Bool = false
    ) -> Effect<Action> {
        state.pendingAnalyticsSessionStatus = status
        let userID = extractUserID(from: status)
        return .run { send in
            guard Task.isCancelled == false else { return }
            await analytics.setUserSession(userID)
            guard Task.isCancelled == false else { return }
            await send(.analyticsSessionConfigured(
                status,
                shouldPresentMarketingConsentAlert: shouldPresentMarketingConsentAlert
            ))
        }
        .cancellable(id: CancelID.analyticsSessionConfiguration, cancelInFlight: true)
    }

    func setAnalyticsSessionEffect(
        state: inout State,
        for status: UserSessionStatus
    ) -> Effect<Action> {
        state.pendingAnalyticsSessionStatus = nil
        let userID = extractUserID(from: status)
        return .run { _ in
            guard Task.isCancelled == false else { return }
            await analytics.setUserSession(userID)
        }
        .cancellable(id: CancelID.analyticsSessionConfiguration, cancelInFlight: true)
    }

    func navigateToNextScreen(
        state: inout State,
        sessionStatus: UserSessionStatus,
        shouldPresentMarketingConsentAlert: Bool = false
    ) -> Effect<Action> {
        appRouter.navigateToNextScreen(
            state: &state,
            sessionStatus: sessionStatus,
            shouldPresentMarketingConsentAlert: shouldPresentMarketingConsentAlert,
            isMarketingConsentAlertEligible: { isMarketingConsentAlertEligible(for: $0) }
        )
    }
    
    func extractUserID(from status: UserSessionStatus) -> Int? {
        guard case let .signedIn(user) = status else { return nil }
        return user.id
    }

    func synchronizePushNotificationIfReady(_ state: inout State) -> Effect<Action> {
        guard case .signedIn = state.userSessionStatus else { return .none }
        guard isAPNSTokenRegistered(&state) else { return .none }

        state.hasSynchronizedPushNotification = false
        guard state.isSynchronizingPushNotification == false else {
            state.shouldRetryPushNotificationSynchronization = true
            return .none
        }
        return .send(.synchronizePushNotification)
    }

    func isAPNSTokenRegistered(_ state: inout State) -> Bool {
        state.isAPNSTokenRegistered = state.isAPNSTokenRegistered || pushNotificationClient.checkAPNSTokenRegistration()
        return state.isAPNSTokenRegistered
    }

    func isMarketingConsentAlertEligible(for user: User) -> Bool {
        guard user.marketingTermAgreed == false else { return false }
        let statusKey = AppStorageKey.marketingConsentManagementStatus(userID: user.id)
        let status = UserDefaults.standard.string(forKey: statusKey)
            .flatMap(MarketingConsentManagementStatus.init(rawValue:)) ?? .unconfirmed
        guard status == .unconfirmed else { return false }

        let countKey = AppStorageKey.marketingConsentAlertPresentationCount(userID: user.id)
        guard UserDefaults.standard.integer(forKey: countKey) < 2 else { return false }

        let managedAtKey = AppStorageKey.marketingConsentLastManagedAt(userID: user.id)
        guard let lastManagedAt = UserDefaults.standard.object(forKey: managedAtKey) as? Date else { return true }

        return now.timeIntervalSince(lastManagedAt) >= Constants.marketingConsentAlertRevisitInterval
    }

    func markMarketingConsentManaged(
        for user: User,
        status: MarketingConsentManagementStatus
    ) {
        UserDefaults.standard.set(
            now,
            forKey: AppStorageKey.marketingConsentLastManagedAt(userID: user.id)
        )
        UserDefaults.standard.set(
            status.rawValue,
            forKey: AppStorageKey.marketingConsentManagementStatus(userID: user.id)
        )
        if status != .unconfirmed {
            UserDefaults.standard.set(
                2,
                forKey: AppStorageKey.marketingConsentAlertPresentationCount(userID: user.id)
            )
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
