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

    @Test("OS 알림 팝업을 띄운 뒤에는 권한을 다시 확인해 서버 동의 값을 한 번 맞춘다")
    func notificationAuthorizationRequested_synchronizesPushAgreementOnce() async {
        var state = AppCoordinator.State()
        state.route = .mainTab(MainTabCoordinator.State())
        state.$userSessionStatus.withLock { $0 = .signedIn(user) }
        let records = LockIsolated<[String]>([])
        let store = makeStore(initialState: state, records: records) {
            $0.pushNotificationClient.checkAPNSTokenRegistration = { true }
            $0.pushNotificationClient.checkAuthorizationStatus = { .authorized }
            $0.pushNotificationClient.synchronizeDeviceToken = {
                records.withValue { $0.append("sync") }
                return .authorized
            }
        }

        await store.send(.route(.mainTab(.delegate(.didRequestNotificationAuthorization)))).finish()

        #expect(records.value == ["sync"])
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
