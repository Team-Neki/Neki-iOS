//
//  NotificationGuideFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/10/26.
//

import ComposableArchitecture
import Foundation
import Testing
import UIKit
import UserNotifications
@testable import Neki_iOS

@MainActor
struct NotificationGuideFeatureTests {
    // MARK: - 업데이트 후 첫 진입

    @Test("오늘 다른 자동 안내를 띄웠으면 모달 없이 넘기고 기록을 바꾸지 않는다")
    func mainTabAppeared_guideShownToday_skipsWithoutRecording() async {
        let records = LockIsolated<[String]>([])
        let seeded = NotificationGuideRecord(lastAutomaticGuideDay: Fixture.today, updateEntryJudgedVersion: "1.4.0")
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        $record.withLock { $0 = seeded }
        let store = makeStore(records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.updateEntryAuthorizationResponse.success)

        #expect(record == seeded)
        #expect(records.value == ["check"])
    }

    @Test("이번 버전을 이미 판단했으면 넘긴다")
    func mainTabAppeared_versionJudged_skips() async {
        let records = LockIsolated<[String]>([])
        let seeded = NotificationGuideRecord(lastAutomaticGuideDay: Fixture.yesterday, updateEntryJudgedVersion: Fixture.version)
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        $record.withLock { $0 = seeded }
        let store = makeStore(records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.updateEntryAuthorizationResponse.success)

        #expect(record == seeded)
    }

    @Test("알림이 켜져 있고 동의도 했으면 모달 없이 이 버전을 판단한 것으로 남긴다")
    func mainTabAppeared_enabledAndAgreed_marksJudged() async {
        let records = LockIsolated<[String]>([])
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        let store = makeStore(isMarketingAgreed: true, authorizationStatus: .authorized, records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.updateEntryAuthorizationResponse.success)

        #expect(record == NotificationGuideRecord(updateEntryJudgedVersion: Fixture.version))
    }

    /// 인자들이 같은 저장소를 쓰므로 순서대로 돌리고, 매번 기록을 새로 넣습니다.
    @Test(
        "알림 권한과 동의 상태에 맞는 모달을 띄우고 버전과 오늘 날짜를 남긴다",
        .serialized,
        arguments: [
            (UNAuthorizationStatus.authorized, false, NotificationGuideModal.consentOnly),
            (.notDetermined, true, .enableNotifications),
            (.notDetermined, false, .consentAndEnable),
            (.denied, true, .openSettings(includesConsent: false)),
            (.denied, false, .openSettings(includesConsent: true))
        ] as [(UNAuthorizationStatus, Bool, NotificationGuideModal)]
    )
    func mainTabAppeared_newVersion_presentsModal(
        status: UNAuthorizationStatus,
        isMarketingAgreed: Bool,
        expected: NotificationGuideModal
    ) async {
        let records = LockIsolated<[String]>([])
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        $record.withLock { $0 = NotificationGuideRecord(lastAutomaticGuideDay: Fixture.yesterday, updateEntryJudgedVersion: "1.4.0") }
        let store = makeStore(isMarketingAgreed: isMarketingAgreed, authorizationStatus: status, records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.updateEntryAuthorizationResponse.success) { $0.modal = expected }

        #expect(record == NotificationGuideRecord(lastAutomaticGuideDay: Fixture.today, updateEntryJudgedVersion: Fixture.version))
    }

    @Test("첫 화면이 다른 화면에 가려져 있으면 판단하지 않고 기록도 남기지 않는다")
    func mainTabAppeared_firstScreenCovered_skips() async {
        let records = LockIsolated<[String]>([])
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        let store = makeStore(records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: true)) { $0.hasStarted = true }

        #expect(records.value.isEmpty)
        #expect(record == NotificationGuideRecord())
    }

    @Test("메인 탭이 다시 나타나도 한 번만 판단한다")
    func mainTabAppeared_twice_judgesOnce() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.updateEntryAuthorizationResponse.success) { $0.modal = .consentAndEnable }
        await store.send(.mainTabAppeared(isFirstScreenCovered: false))

        #expect(records.value == ["check"])
    }

    @Test("알림 권한을 확인하지 못하면 기록하지 않는다")
    func mainTabAppeared_authorizationCheckFails_recordsNothing() async {
        let records = LockIsolated<[String]>([])
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        let store = makeStore(records: records) { _ in } dependencies: {
            $0.pushNotificationClient.checkAuthorizationStatus = { throw Failure() }
        }

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.updateEntryAuthorizationResponse.failure)

        #expect(record == NotificationGuideRecord())
    }

    // MARK: - 확인 버튼

    @Test("동의만 모달은 동의만 저장하고 바로 토스트를 띄운다")
    func confirm_consentOnly_savesConsentAndShowsToast() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(authorizationStatus: .authorized, records: records) { $0.modal = .consentOnly }

        await store.send(.confirmButtonTapped) { $0.isProcessing = true }
        await store.receive(\.marketingConsentResponse) {
            $0.$userSessionStatus.withLock { $0 = .signedIn(Fixture.user(isMarketingAgreed: true)) }
            $0.modal = nil
            $0.isProcessing = false
        }
        await store.receive(Self.isToast(Fixture.agreedToastMessage))

        #expect(records.value == ["consent"])
    }

    @Test("통합 모달은 동의를 저장한 뒤 OS 알림 팝업을 띄우고, 팝업이 끝난 뒤에 토스트를 띄운다")
    func confirm_consentAndEnable_requestsAuthorizationThenShowsToast() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records) { $0.modal = .consentAndEnable }

        await store.send(.confirmButtonTapped) { $0.isProcessing = true }
        await store.receive(\.marketingConsentResponse) {
            $0.$userSessionStatus.withLock { $0 = .signedIn(Fixture.user(isMarketingAgreed: true)) }
            $0.consentAgreedAt = Fixture.now
            $0.modal = nil
        }
        await store.receive(\.authorizationRequestFinished) {
            $0.isProcessing = false
            $0.consentAgreedAt = nil
        }
        await store.receive(Self.isAuthorizationRequestDelegate)
        await store.receive(Self.isToast(Fixture.agreedToastMessage))

        #expect(records.value == ["consent", "request"])
    }

    @Test("OS 알림 팝업 요청이 실패해도 거부와 같이 마무리하고 저장한 동의는 토스트로 알린다")
    func confirm_consentAndEnable_requestFails_keepsConsent() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records) {
            $0.modal = .consentAndEnable
        } dependencies: {
            $0.pushNotificationClient.requestAuthorization = {
                records.withValue { $0.append("request") }
                throw Failure()
            }
        }

        await store.send(.confirmButtonTapped) { $0.isProcessing = true }
        await store.receive(\.marketingConsentResponse) {
            $0.$userSessionStatus.withLock { $0 = .signedIn(Fixture.user(isMarketingAgreed: true)) }
            $0.consentAgreedAt = Fixture.now
            $0.modal = nil
        }
        await store.receive(\.authorizationRequestFinished) {
            $0.isProcessing = false
            $0.consentAgreedAt = nil
        }
        await store.receive(Self.isAuthorizationRequestDelegate)
        await store.receive(Self.isToast(Fixture.agreedToastMessage))

        #expect(records.value == ["consent", "request"])
    }

    @Test("알림 켜기 모달은 OS 알림 팝업만 띄우고 토스트는 띄우지 않는다")
    func confirm_enableNotifications_requestsAuthorizationOnly() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(isMarketingAgreed: true, records: records) { $0.modal = .enableNotifications }

        await store.send(.confirmButtonTapped) {
            $0.isProcessing = true
            $0.modal = nil
        }
        await store.receive(\.authorizationRequestFinished) { $0.isProcessing = false }
        await store.receive(Self.isAuthorizationRequestDelegate)

        #expect(records.value == ["request"])
    }

    @Test("동의하지 않은 사용자의 설정 모달은 동의를 저장하고, 설정에서 돌아오면 토스트를 띄운다")
    func confirm_openSettingsWithConsent_showsToastAfterReturning() async {
        let records = LockIsolated<[String]>([])
        let openedURLs = LockIsolated<[URL]>([])
        let store = makeStore(authorizationStatus: .denied, records: records) {
            $0.modal = .openSettings(includesConsent: true)
        } dependencies: {
            $0.openURL = OpenURLEffect { url in
                records.withValue { $0.append("open") }
                openedURLs.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.confirmButtonTapped) { $0.isProcessing = true }
        await store.receive(\.marketingConsentResponse) {
            $0.$userSessionStatus.withLock { $0 = .signedIn(Fixture.user(isMarketingAgreed: true)) }
            $0.consentAgreedAt = Fixture.now
            $0.modal = nil
            $0.isAwaitingSettingsReturn = true
        }
        await store.receive(\.notificationSettingsOpened)
        await store.send(.sceneDidBecomeActive) {
            $0.isAwaitingSettingsReturn = false
            $0.isProcessing = false
            $0.consentAgreedAt = nil
        }
        await store.receive(Self.isToast(Fixture.agreedToastMessage))

        #expect(records.value == ["consent", "open"])
        #expect(openedURLs.value == [URL(string: UIApplication.openNotificationSettingsURLString)])
    }

    @Test("동의한 사용자의 설정 모달은 설정만 열고 토스트는 띄우지 않는다")
    func confirm_openSettingsWithoutConsent_opensSettingsOnly() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(isMarketingAgreed: true, authorizationStatus: .denied, records: records) {
            $0.modal = .openSettings(includesConsent: false)
        }

        await store.send(.confirmButtonTapped) {
            $0.isProcessing = true
            $0.modal = nil
            $0.isAwaitingSettingsReturn = true
        }
        await store.receive(\.notificationSettingsOpened)
        await store.send(.sceneDidBecomeActive) {
            $0.isAwaitingSettingsReturn = false
            $0.isProcessing = false
        }

        #expect(records.value == ["open"])
    }

    @Test("설정을 열지 못하면 바로 마무리하고, 저장한 동의는 토스트로 알린다")
    func confirm_openSettingsFails_finishesWithToast() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(authorizationStatus: .denied, records: records) {
            $0.modal = .openSettings(includesConsent: true)
        } dependencies: {
            $0.openURL = OpenURLEffect { _ in false }
        }

        await store.send(.confirmButtonTapped) { $0.isProcessing = true }
        await store.receive(\.marketingConsentResponse) {
            $0.$userSessionStatus.withLock { $0 = .signedIn(Fixture.user(isMarketingAgreed: true)) }
            $0.consentAgreedAt = Fixture.now
            $0.modal = nil
            $0.isAwaitingSettingsReturn = true
        }
        await store.receive(\.notificationSettingsOpened) {
            $0.isAwaitingSettingsReturn = false
            $0.isProcessing = false
            $0.consentAgreedAt = nil
        }
        await store.receive(Self.isToast(Fixture.agreedToastMessage))
    }

    @Test("설정으로 보내지 않았으면 앱이 다시 활성화돼도 아무것도 하지 않는다")
    func sceneDidBecomeActive_notAwaitingSettings_isIgnored() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records)

        await store.send(.sceneDidBecomeActive)

        #expect(records.value.isEmpty)
    }

    @Test("동의 저장에 실패하면 모달을 그대로 두고 실패 토스트를 띄운다")
    func confirm_consentFails_keepsModalAndShowsError() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records) {
            $0.modal = .consentAndEnable
        } dependencies: {
            $0.authClient.updateMarketingConsent = { _ in
                records.withValue { $0.append("consent") }
                throw Failure()
            }
        }

        await store.send(.confirmButtonTapped) { $0.isProcessing = true }
        await store.receive(\.marketingConsentResponse) { $0.isProcessing = false }
        await store.receive(Self.isToast("이벤트·혜택 알림 동의에 실패했어요"))

        #expect(store.state.modal == .consentAndEnable)
        #expect(records.value == ["consent"])
    }

    // MARK: - 다음에 하기

    @Test("다음에 하기를 누르면 모달만 닫는다")
    func cancel_closesModal() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records) { $0.modal = .consentOnly }

        await store.send(.cancelButtonTapped) { $0.modal = nil }

        #expect(records.value.isEmpty)
    }

    @Test("처리 중에는 다음에 하기를 무시한다")
    func cancel_whileProcessing_isIgnored() async {
        let records = LockIsolated<[String]>([])
        let store = makeStore(records: records) {
            $0.modal = .consentAndEnable
            $0.isProcessing = true
        }

        await store.send(.cancelButtonTapped)
    }

    // MARK: - 약관 동의 뒤 진입

    @Test("약관에서 이벤트·혜택 알림에 동의했고 아직 묻지 않았으면 모달 없이 OS 알림 팝업을 띄운다")
    func mainTabAppeared_afterTermsWithConsent_requestsAuthorization() async {
        let records = LockIsolated<[String]>([])
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        let store = makeStore(entry: .afterTermsAgreement(isMarketingTermAgreed: true), isMarketingAgreed: true, records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.termsEntryAuthorizationResponse.success) { $0.isProcessing = true }
        await store.receive(\.authorizationRequestFinished) { $0.isProcessing = false }
        await store.receive(Self.isAuthorizationRequestDelegate)

        #expect(records.value == ["check", "request"])
        #expect(record == NotificationGuideRecord(lastAutomaticGuideDay: Fixture.today, updateEntryJudgedVersion: Fixture.version))
    }

    @Test("약관에서 이벤트·혜택 알림에 동의하지 않았으면 아무것도 띄우지 않고 이 버전을 판단한 것으로 남긴다")
    func mainTabAppeared_afterTermsWithoutConsent_marksJudgedOnly() async {
        let records = LockIsolated<[String]>([])
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        let store = makeStore(entry: .afterTermsAgreement(isMarketingTermAgreed: false), records: records)

        await store.send(.mainTabAppeared(isFirstScreenCovered: true)) { $0.hasStarted = true }

        #expect(records.value.isEmpty)
        #expect(record == NotificationGuideRecord(updateEntryJudgedVersion: Fixture.version))
    }

    /// 인자들이 같은 저장소를 쓰므로 순서대로 돌리고, 매번 기록을 비웁니다.
    @Test(
        "약관에서 동의했어도 이미 알림 권한을 정했으면 OS 알림 팝업을 띄우지 않는다",
        .serialized,
        arguments: [UNAuthorizationStatus.authorized, .denied]
    )
    func mainTabAppeared_afterTermsAlreadyDecided_doesNotRequest(status: UNAuthorizationStatus) async {
        let records = LockIsolated<[String]>([])
        @Shared(.appStorage(AppStorageKey.notificationGuideRecord(userID: Fixture.userID))) var record = NotificationGuideRecord()
        $record.withLock { $0 = NotificationGuideRecord() }
        let store = makeStore(
            entry: .afterTermsAgreement(isMarketingTermAgreed: true),
            isMarketingAgreed: true,
            authorizationStatus: status,
            records: records
        )

        await store.send(.mainTabAppeared(isFirstScreenCovered: false)) { $0.hasStarted = true }
        await store.receive(\.termsEntryAuthorizationResponse.success)

        #expect(records.value == ["check"])
        #expect(record == NotificationGuideRecord(updateEntryJudgedVersion: Fixture.version))
    }
}

// MARK: - Helpers

private extension NotificationGuideFeatureTests {
    /// 로그인한 사용자로 알림 안내 스토어를 만듭니다. 부른 클라이언트는 `records`에 이름으로 남깁니다.
    func makeStore(
        entry: NotificationGuideEntry = .regular,
        isMarketingAgreed: Bool = false,
        authorizationStatus: UNAuthorizationStatus = .notDetermined,
        records: LockIsolated<[String]>,
        update: (inout NotificationGuideFeature.State) -> Void = { _ in },
        dependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<NotificationGuideFeature> {
        var state = NotificationGuideFeature.State(entry: entry)
        state.$userSessionStatus.withLock { $0 = .signedIn(Fixture.user(isMarketingAgreed: isMarketingAgreed)) }
        update(&state)

        return TestStore(initialState: state) {
            NotificationGuideFeature()
        } withDependencies: {
            $0.date.now = Fixture.now
            $0.appVersionClient.currentVersion = { AppVersion(value: Fixture.version) }
            $0.pushNotificationClient.checkAuthorizationStatus = {
                records.withValue { $0.append("check") }
                return authorizationStatus
            }
            $0.pushNotificationClient.requestAuthorization = {
                records.withValue { $0.append("request") }
                return true
            }
            $0.authClient.updateMarketingConsent = { _ in
                records.withValue { $0.append("consent") }
            }
            $0.openURL = OpenURLEffect { _ in
                records.withValue { $0.append("open") }
                return true
            }
            dependencies(&$0)
        }
    }

    static func isToast(_ message: String) -> (NotificationGuideFeature.Action) -> Bool {
        { action in
            guard case let .delegate(.showToast(item)) = action else { return false }
            return item.message == message
        }
    }

    static func isAuthorizationRequestDelegate(_ action: NotificationGuideFeature.Action) -> Bool {
        guard case .delegate(.didRequestNotificationAuthorization) = action else { return false }
        return true
    }
}

private enum Fixture {
    static let userID = 7
    static let version = "1.4.1"
    /// 2026-11-10 10:00 한국 시간
    static let now = Date(timeIntervalSince1970: 1_794_272_400)
    static let today = KSTDay(year: 2026, month: 11, day: 10)
    static let yesterday = KSTDay(year: 2026, month: 11, day: 9)
    static let agreedToastMessage = "11.10 이벤트·혜택 알림에 동의했어요."

    static func user(isMarketingAgreed: Bool) -> User {
        User(
            id: userID,
            nickname: "네키",
            email: nil,
            profileImageURL: nil,
            providerType: .test,
            allRequiredTermsAgreed: true,
            marketingTermAgreed: isMarketingAgreed
        )
    }
}

private struct Failure: Error {}
