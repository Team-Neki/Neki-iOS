//
//  NotificationGuideFeature.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/10/26.
//

import ComposableArchitecture
import Foundation
import os
import UIKit
import UserNotifications

/// 알림 권한과 이벤트·혜택 알림 동의를 안내합니다.
///
/// - 약관 동의를 마치고 들어오면, 이벤트·혜택 알림에 동의한 경우 모달 없이 OS 알림 팝업을 띄웁니다.
/// - 그 밖에는 앱 버전마다 한 번 상태에 맞는 모달을 띄웁니다. 자동 안내는 하루에 한 번만 띄웁니다.
/// - 공유로 사진을 가져오는 실행에서는 모달이 앨범 선택 화면을 막지 않도록 띄우지 않습니다.
@Reducer
struct NotificationGuideFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut

        var entry: NotificationGuideEntry
        var hasStarted: Bool = false
        var modal: NotificationGuideModal?
        var isProcessing: Bool = false
        var isAwaitingSettingsReturn: Bool = false
        var consentAgreedAt: Date?
        /// 이번 실행에서 공유로 사진 가져오기가 시작돼 업데이트 후 첫 진입 모달을 띄우지 않는지입니다.
        /// 기록을 남기지 않으므로 다음 실행에서 다시 판단합니다.
        var isSuppressedByShare: Bool = false

        var user: User? {
            guard case let .signedIn(user) = userSessionStatus else { return nil }
            return user
        }

        init(entry: NotificationGuideEntry = .regular) {
            self.entry = entry
        }
    }

    enum Action {
        // Parent Actions
        case mainTabAppeared(isFirstScreenCovered: Bool)
        case sceneDidBecomeActive
        case shareEntryStarted

        // View Actions
        case confirmButtonTapped
        case cancelButtonTapped

        // Internal Actions
        case termsEntryAuthorizationResponse(Result<UNAuthorizationStatus, Error>)
        case updateEntryAuthorizationResponse(Result<UNAuthorizationStatus, Error>)
        case marketingConsentResponse(Result<Void, Error>)
        case authorizationRequestFinished
        case notificationSettingsOpened(Bool)

        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
            case didRequestNotificationAuthorization
        }
    }

    @Dependency(\.authClient) private var authClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    @Dependency(\.appVersionClient) private var appVersionClient
    @Dependency(\.openURL) private var openURL
    @Dependency(\.date.now) private var now

    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .mainTabAppeared(isFirstScreenCovered):
                guard state.hasStarted == false, let user = state.user else { return .none }
                state.hasStarted = true

                switch state.entry {
                case let .afterTermsAgreement(isMarketingTermAgreed):
                    let appVersion = appVersionClient.currentVersion().value
                    guideRecord(for: user).withLock { $0.updateEntryJudgedVersion = appVersion }
                    guard isMarketingTermAgreed else { return .none }
                    return .run { send in
                        await send(.termsEntryAuthorizationResponse(Result {
                            try await pushNotificationClient.checkAuthorizationStatus()
                        }))
                    }

                case .regular:
                    guard isFirstScreenCovered == false, state.isSuppressedByShare == false else { return .none }
                    return .run { send in
                        await send(.updateEntryAuthorizationResponse(Result {
                            try await pushNotificationClient.checkAuthorizationStatus()
                        }))
                    }
                }

            case let .termsEntryAuthorizationResponse(.success(status)):
                guard NotificationPermission(status) == .requestable, let user = state.user else { return .none }
                let today = now.kstDay
                guideRecord(for: user).withLock { $0.lastAutomaticGuideDay = today }
                state.isProcessing = true
                return requestAuthorization()

            case let .termsEntryAuthorizationResponse(.failure(error)):
                Logger.presentation.error("약관 동의 뒤 알림 권한 확인 실패: \(error)")
                return .none

            case let .updateEntryAuthorizationResponse(.success(status)):
                // 권한을 확인하는 사이에 공유가 들어왔으면 기록 없이 넘깁니다.
                guard state.isSuppressedByShare == false, let user = state.user else { return .none }
                let today = now.kstDay
                let appVersion = appVersionClient.currentVersion().value
                let record = guideRecord(for: user)
                let decision = NotificationGuideDecision.updateEntry(
                    record: record.wrappedValue,
                    today: today,
                    appVersion: appVersion,
                    permission: NotificationPermission(status),
                    isMarketingAgreed: user.marketingTermAgreed
                )
                record.withLock { $0.apply(decision, today: today, appVersion: appVersion) }
                if case let .present(modal) = decision { state.modal = modal }
                return .none

            case let .updateEntryAuthorizationResponse(.failure(error)):
                Logger.presentation.error("업데이트 후 첫 진입 알림 권한 확인 실패: \(error)")
                return .none

            case .confirmButtonTapped:
                guard let modal = state.modal, state.isProcessing == false else { return .none }
                state.isProcessing = true
                guard modal.savesMarketingConsent else { return proceed(&state, after: modal) }
                return .run { send in
                    await send(.marketingConsentResponse(Result {
                        try await authClient.updateMarketingConsent(true)
                    }))
                }

            case .marketingConsentResponse(.success):
                guard let modal = state.modal else { return finish(&state) }
                state.$userSessionStatus.withLock { status in
                    guard case var .signedIn(user) = status else { return }
                    user.marketingTermAgreed = true
                    status = .signedIn(user)
                }
                state.consentAgreedAt = now
                return proceed(&state, after: modal)

            case let .marketingConsentResponse(.failure(error)):
                Logger.presentation.error("이벤트·혜택 알림 동의 저장 실패: \(error)")
                state.isProcessing = false
                return .send(.delegate(.showToast(.marketingConsentFailed())))

            case .cancelButtonTapped:
                guard state.modal != nil, state.isProcessing == false else { return .none }
                state.modal = nil
                return .none

            case .authorizationRequestFinished:
                let finishEffect = finish(&state)
                return .concatenate(
                    .send(.delegate(.didRequestNotificationAuthorization)),
                    finishEffect
                )

            case let .notificationSettingsOpened(isOpened):
                guard isOpened == false else { return .none }
                state.isAwaitingSettingsReturn = false
                return finish(&state)

            case .sceneDidBecomeActive:
                guard state.isAwaitingSettingsReturn else { return .none }
                state.isAwaitingSettingsReturn = false
                return finish(&state)

            case .shareEntryStarted:
                state.isSuppressedByShare = true
                // 동의를 저장하는 중이면 저장 결과가 와서 다음 단계로 넘어갈 때까지 모달을 둡니다.
                guard state.isProcessing == false else { return .none }
                // 이미 띄운 모달은 닫습니다. 띄운 기록은 남아 있어 "다음에 하기"처럼 이 버전에서는 다시 띄우지 않습니다.
                state.modal = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

private extension NotificationGuideFeature {
    func guideRecord(for user: User) -> Shared<NotificationGuideRecord> {
        Shared(
            wrappedValue: NotificationGuideRecord(),
            .appStorage(AppStorageKey.notificationGuideRecord(userID: user.id))
        )
    }

    /// 모달을 닫고 확인 뒤 할 일을 이어 갑니다.
    func proceed(_ state: inout State, after modal: NotificationGuideModal) -> Effect<Action> {
        state.modal = nil
        switch modal.nextStep {
        case .complete:
            return finish(&state)

        case .requestAuthorization:
            return requestAuthorization()

        case .openNotificationSettings:
            state.isAwaitingSettingsReturn = true
            return .run { send in
                guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
                    await send(.notificationSettingsOpened(false))
                    return
                }
                await send(.notificationSettingsOpened(await openURL(url)))
            }
        }
    }

    /// OS 알림 팝업을 띄웁니다. 요청이 실패해도 거부한 것과 같이 마무리합니다.
    func requestAuthorization() -> Effect<Action> {
        .run { send in
            do {
                _ = try await pushNotificationClient.requestAuthorization()
            } catch {
                Logger.presentation.error("알림 권한 요청 실패: \(error)")
            }
            await send(.authorizationRequestFinished)
        }
    }

    /// 안내를 마칩니다. 동의를 저장했으면 OS 팝업이나 설정이 끝난 뒤에 토스트를 띄웁니다.
    func finish(_ state: inout State) -> Effect<Action> {
        state.isProcessing = false
        guard let consentAgreedAt = state.consentAgreedAt else { return .none }
        state.consentAgreedAt = nil
        return .send(.delegate(.showToast(.marketingConsentAgreed(at: consentAgreedAt))))
    }
}
