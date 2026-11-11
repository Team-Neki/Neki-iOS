//
//  AppCoordinatorTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import UserNotifications
@testable import Neki_iOS

@MainActor
struct AppCoordinatorTests {
    @Test("앱을 실행해 자동 로그인에 성공하면 사용자를 지정한 뒤 앱 실행을 한 번 남긴다")
    func splashSequenceCompleted_afterAutoLogin_logsAppOpenAfterSettingUser() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records)

        await store.send(.splashSequenceCompleted(.signedIn(user), versionResult(.upToDate))).finish()

        #expect(records.value == ["user \(user.id)", "app_open"])
    }

    @Test("자동 로그인 없이 스플래시를 벗어나면 앱 실행을 남기지 않는다")
    func splashSequenceCompleted_signedOut_doesNotLogAppOpen() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records)

        await store.send(.splashSequenceCompleted(.signedOut, versionResult(.upToDate))).finish()

        #expect(records.value == ["user nil"])
    }

    @Test("자동 로그인 뒤 선택 업데이트 안내가 뜨면, 안내를 닫고 메인으로 갈 때 앱 실행을 남긴다")
    func didTapLaterAlert_afterAutoLogin_logsAppOpen() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records)

        await store.send(.splashSequenceCompleted(.signedIn(user), versionResult(.optionalUpdate))).finish()
        #expect(records.value == ["user \(user.id)"])

        await store.send(.didTapLaterAlert).finish()

        #expect(records.value == ["user \(user.id)", "user \(user.id)", "app_open"])
    }

    @Test(
        "업데이트 안내 바깥을 누르면 새 버전 안내는 닫고, 필수 업데이트 안내는 닫지 않는다",
        arguments: [
            (AppUpdateStatus.optionalUpdate, nil),
            (.mustUpdate, .updateNeeded)
        ] as [(AppUpdateStatus, AppCoordinator.VersionUpdateAlertType?)]
    )
    func didTapLaterAlert_closesOnlyOptionalUpdate(
        status: AppUpdateStatus,
        expected: AppCoordinator.VersionUpdateAlertType?
    ) async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records)

        await store.send(.splashSequenceCompleted(.signedIn(user), versionResult(status))).finish()
        await store.send(.didTapLaterAlert).finish()

        #expect(store.versionAlert == expected)
    }

    @Test("로그인 화면에서 새로 로그인하면 앱 실행을 남기지 않는다")
    func moveToMainTab_afterNewLogin_doesNotLogAppOpen() async {
        var state = AppCoordinator.State()
        state.route = .auth(LoginCoordinator.State())
        let records = LockIsolated<[String]>([])
        let store = makeStore(initialState: state, records: records)

        await store.send(.route(.auth(.delegate(.moveToMainTab(user, notificationGuideEntry: .regular))))).finish()

        #expect(records.value == ["user \(user.id)"])
    }

    @Test("앱에서 약관 동의를 마치면 이벤트·혜택 알림 체크 여부를 알림 안내 진입 경로로 넘긴다")
    func termsAgreementFinished_passesMarketingTermToNotificationGuide() async {
        var state = AppCoordinator.State()
        state.route = .termsAgreement(TermsAgreementFeature.State())
        let records = LockIsolated<[String]>([])
        let store = makeStore(initialState: state, records: records)

        await store.send(.route(.termsAgreement(.didFinishOnboarding(user, isMarketingTermAgreed: true)))).finish()

        #expect(mainTab(of: store)?.notificationGuide.entry == .afterTermsAgreement(isMarketingTermAgreed: true))
    }

    @Test("로그인 경로에서 받은 알림 안내 진입 경로를 메인 탭까지 넘긴다")
    func moveToMainTab_passesNotificationGuideEntry() async {
        var state = AppCoordinator.State()
        state.route = .auth(LoginCoordinator.State())
        let records = LockIsolated<[String]>([])
        let store = makeStore(initialState: state, records: records)

        await store.send(.route(.auth(.delegate(.moveToMainTab(
            user,
            notificationGuideEntry: .afterTermsAgreement(isMarketingTermAgreed: false)
        ))))).finish()

        #expect(mainTab(of: store)?.notificationGuide.entry == .afterTermsAgreement(isMarketingTermAgreed: false))
    }

    @Test("자동 로그인으로 메인에 들어가면 업데이트 후 첫 진입 안내를 판단한다")
    func splashSequenceCompleted_afterAutoLogin_usesRegularNotificationGuideEntry() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records)

        await store.send(.splashSequenceCompleted(.signedIn(user), versionResult(.upToDate))).finish()

        #expect(mainTab(of: store)?.notificationGuide.entry == .regular)
    }

    @Test("앱이 다시 활성화되면 메인 탭 알림 안내에 알려 설정에서 돌아온 것을 마무리한다")
    func scenePhaseChanged_active_forwardsToNotificationGuide() async {
        var mainTabState = MainTabCoordinator.State()
        mainTabState.notificationGuide.isAwaitingSettingsReturn = true
        var state = AppCoordinator.State()
        state.route = .mainTab(mainTabState)
        state.lastVersionCheckedTime = Date(timeIntervalSince1970: 0)
        let records = LockIsolated<[String]>([])
        let store = makeStore(initialState: state, records: records)

        await store.send(.scenePhaseChanged(.active)).finish()

        #expect(mainTab(of: store)?.notificationGuide.isAwaitingSettingsReturn == false)
    }

    @Test(
        "OS 알림 팝업에 어떻게 답해도, 앱이 다시 활성화되면 서버 push 동의를 알림 권한에 맞추고 같은 동기화를 두 번 보내지 않는다",
        arguments: PopupAnswer.all, PopupTiming.all
    )
    func notificationPopupAnswered_synchronizesPushAgreementOnce(answer: PopupAnswer, timing: PopupTiming) async {
        let authorizationStatus = LockIsolated(UNAuthorizationStatus.notDetermined)
        let synchronizations = LockIsolated(0)
        let popupAnswered = AsyncStream<Void>.makeStream()
        let serverResponded = AsyncStream<Void>.makeStream()
        var mainTabState = MainTabCoordinator.State()
        mainTabState.notificationGuide.modal = .enableNotifications
        var state = AppCoordinator.State()
        state.route = .mainTab(mainTabState)
        state.$userSessionStatus.withLock { $0 = .signedIn(user) }
        state.lastVersionCheckedTime = Date(timeIntervalSince1970: 0)
        if timing.hasSynchronizedAtLaunch {
            // 실행 때는 아직 묻지 않은 상태라 서버에 동의 안 함으로 맞춰 둔 상태입니다.
            state.hasSynchronizedPushNotification = true
            state.lastSynchronizedPushAgreement = false
        }
        let store = makeStore(initialState: state, records: LockIsolated([])) {
            $0.pushNotificationClient.checkAPNSTokenRegistration = { true }
            $0.pushNotificationClient.checkAuthorizationStatus = { authorizationStatus.value }
            $0.pushNotificationClient.requestAuthorization = {
                // 사용자가 OS 팝업에 답할 때까지 기다립니다.
                for await _ in popupAnswered.stream { break }
                return answer.isPushAgreed
            }
            $0.pushNotificationClient.synchronizeDeviceToken = {
                synchronizations.withValue { $0 += 1 }
                // 서버 응답을 기다리는 사이에 다른 권한 확인이 끼어들 수 있게 합니다.
                for await _ in serverResponded.stream {}
                return authorizationStatus.value
            }
        }

        let confirm = store.send(.route(.mainTab(.notificationGuide(.confirmButtonTapped))))
        // 사용자가 팝업에 답한 뒤 "팝업 끝남"과 "앱 활성화" 중 무엇이 먼저 올지는 정해져 있지 않습니다.
        authorizationStatus.setValue(answer.status)
        let activation: StoreTask
        if timing.isActivatedFirst {
            activation = store.send(.scenePhaseChanged(.active))
            await Task.megaYield()
            popupAnswered.continuation.yield()
            await waitUntilPopupFinished(store)
        } else {
            popupAnswered.continuation.yield()
            await waitUntilPopupFinished(store)
            activation = store.send(.scenePhaseChanged(.active))
        }
        await Task.megaYield()
        serverResponded.continuation.finish()
        await confirm.finish()
        await activation.finish()

        #expect(synchronizations.value == timing.expectedSynchronizations(after: answer))
        #expect(store.lastSynchronizedPushAgreement == answer.isPushAgreed)
    }
}


// MARK: - Helpers

private extension AppCoordinatorTests {
    /// 사용자 지정과 보낸 분석 이벤트를 `records`에 차례로 모읍니다.
    ///
    /// `AppCoordinator.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    /// 메인으로 가면 푸시 권한을 확인하므로, 권한은 거부로 두고 APNs 토큰은 없는 것으로 둡니다. 바꿀 것은 `dependencies`로 덮어씁니다.
    func makeStore(
        initialState: AppCoordinator.State = .init(),
        records: LockIsolated<[String]>,
        dependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> StoreOf<AppCoordinator> {
        Store(initialState: initialState) {
            AppCoordinator()
        } withDependencies: {
            $0.analyticsClient.setUserSession = { userID in
                records.withValue { $0.append("user \(userID.map(String.init) ?? "nil")") }
            }
            $0.analyticsClient.logEvent = { event in
                records.withValue { $0.append(event.name.value) }
            }
            $0.authClient.observeSessionExpiration = { AsyncStream { $0.finish() } }
            $0.pushNotificationClient.checkAPNSTokenRegistration = { false }
            $0.pushNotificationClient.checkAuthorizationStatus = { .denied }
            $0.uuid = .incrementing
            $0.date.now = Date(timeIntervalSince1970: 0)
            dependencies(&$0)
        }
    }

    func mainTab(of store: StoreOf<AppCoordinator>) -> MainTabCoordinator.State? {
        guard case let .mainTab(state) = store.route else { return nil }
        return state
    }

    /// OS 팝업이 끝났다는 응답을 알림 안내가 처리할 때까지 기다리고, 이어지는 효과가 돌 틈을 줍니다.
    /// 테스트 호스트 앱이 메인 스레드를 쓰는 동안 늦어질 수 있어 넉넉히 기다립니다.
    func waitUntilPopupFinished(_ store: StoreOf<AppCoordinator>) async {
        let deadline = Date().addingTimeInterval(10)
        while mainTab(of: store)?.notificationGuide.isProcessing == true {
            guard Date() < deadline else {
                Issue.record("OS 팝업이 끝난 뒤에도 알림 안내가 처리 중입니다.")
                return
            }
            await Task.yield()
        }
        await Task.megaYield()
    }

    /// 필수 약관에 모두 동의해 메인으로 가는 테스트 사용자입니다.
    var user: User {
        User(
            id: 900_001,
            nickname: "테스트",
            email: nil,
            profileImageURL: nil,
            providerType: .test,
            allRequiredTermsAgreed: true
        )
    }

    func versionResult(_ status: AppUpdateStatus) -> AppVersionClient.VersionResult {
        (AppVersion(value: "1.0.0"), AppVersion(value: "1.0.0"), status)
    }
}

extension AppCoordinatorTests {
    /// OS 알림 팝업 뒤에 읽힐 수 있는 알림 권한 상태 전부와, 그 상태일 때 서버에 맞출 push 동의 값입니다.
    struct PopupAnswer: Sendable, CustomTestStringConvertible {
        let status: UNAuthorizationStatus
        let isPushAgreed: Bool
        let testDescription: String

        static let all: [PopupAnswer] = [
            PopupAnswer(status: .authorized, isPushAgreed: true, testDescription: "authorized"),
            PopupAnswer(status: .provisional, isPushAgreed: true, testDescription: "provisional"),
            PopupAnswer(status: .ephemeral, isPushAgreed: true, testDescription: "ephemeral"),
            PopupAnswer(status: .denied, isPushAgreed: false, testDescription: "denied"),
            PopupAnswer(status: .notDetermined, isPushAgreed: false, testDescription: "notDetermined")
        ]
    }

    /// "팝업 끝남"과 "앱 활성화" 중 무엇이 먼저 오는지, 실행 때 서버 push 동의를 맞춰 뒀는지입니다.
    struct PopupTiming: Sendable, CustomTestStringConvertible {
        let isActivatedFirst: Bool
        let hasSynchronizedAtLaunch: Bool

        static let all: [PopupTiming] = [
            PopupTiming(isActivatedFirst: false, hasSynchronizedAtLaunch: true),
            PopupTiming(isActivatedFirst: true, hasSynchronizedAtLaunch: true),
            PopupTiming(isActivatedFirst: false, hasSynchronizedAtLaunch: false),
            PopupTiming(isActivatedFirst: true, hasSynchronizedAtLaunch: false)
        ]

        var testDescription: String {
            let order = isActivatedFirst ? "앱 활성화 먼저" : "팝업 끝남 먼저"
            let launch = hasSynchronizedAtLaunch ? "실행 때 동기화함" : "실행 때 동기화 못 함"
            return "\(order), \(launch)"
        }

        /// 실행 때 맞춰 뒀으면 동의 값이 바뀐 경우에만 한 번, 아직 맞추지 못했으면 늘 한 번 맞춥니다.
        func expectedSynchronizations(after answer: PopupAnswer) -> Int {
            guard hasSynchronizedAtLaunch else { return 1 }
            return answer.isPushAgreed ? 1 : 0
        }
    }
}
