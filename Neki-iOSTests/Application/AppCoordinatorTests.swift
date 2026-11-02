//
//  AppCoordinatorTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
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

        await store.send(.route(.auth(.delegate(.moveToMainTab(
            user,
            shouldPresentMarketingConsentAlert: false,
            didCompleteTermsAgreement: false,
            marketingConsentStatus: nil
        ))))).finish()

        #expect(records.value == ["user \(user.id)"])
    }
}


// MARK: - Helpers

private extension AppCoordinatorTests {
    /// 사용자 지정과 보낸 분석 이벤트를 `records`에 차례로 모읍니다.
    ///
    /// `AppCoordinator.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    /// 메인으로 가면 푸시 권한을 확인하므로, 권한은 거부로 두고 APNs 토큰은 없는 것으로 둡니다.
    func makeStore(
        initialState: AppCoordinator.State = .init(),
        records: LockIsolated<[String]>
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
        }
    }

    /// 마케팅 동의 안내 기록이 남아 있을 리 없는 사용자입니다. 필수 약관에 모두 동의해 메인으로 갑니다.
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
