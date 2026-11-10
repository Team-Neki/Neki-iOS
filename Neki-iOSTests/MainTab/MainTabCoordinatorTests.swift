//
//  MainTabCoordinatorTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/15/26.
//

import ComposableArchitecture
import Foundation
import Testing
import UserNotifications
@testable import Neki_iOS

@MainActor
struct MainTabCoordinatorTests {
    @Test("지도 탭으로 바뀌면 지도에 알려 반영 중이던 검색을 끝낸다")
    func tabChanged_toMap_resetsMap() {
        let store = makeStore()

        store.send(.tabChanged(.map))

        #expect(store.map.root.appliedSearchQuery == nil)
    }

    @Test("다른 탭으로 바뀌면 지도 상태를 건드리지 않는다")
    func tabChanged_toOtherTab_keepsMap() {
        let store = makeStore()

        store.send(.tabChanged(.archive))

        #expect(store.map.root.appliedSearchQuery?.rawValue == "강남")
    }

    @Test("탭이 바뀌어도 메인 탭은 화면 진입 이벤트를 보내지 않는다. 각 탭의 첫 화면이 보일 때 그 화면이 보낸다")
    func tabChanged_doesNotLogScreenView() async {
        let events = LockIsolated<[String]>([])
        let store = makeStore(events: events)

        await store.send(.tabChanged(.pose)).finish()
        await store.send(.tabChanged(.map)).finish()
        await store.send(.tabChanged(.archive)).finish()

        #expect(events.value.isEmpty)
    }

    @Test(
        "QR·알림 목록이 닫혀 탭 첫 화면이 그대로 보이면 그 화면이 화면 진입 이벤트를 남긴다",
        arguments: zip([NekiTab.archive, .pose, .map], ["archiving_view", "pose_view", "map_view"])
    )
    func fullScreenCoverDismissed_logsVisibleFirstScreen(tab: NekiTab, eventName: String) async {
        let covers: [MainTabCoordinator.Destination.State] = [
            .qrScan(QRCodeScanFeature.State(user: .dummy)),
            .notificationList(PushNotificationListFeature.State()),
        ]
        for cover in covers {
            let events = LockIsolated<[String]>([])
            let store = makeStore(events: events) {
                $0.selectedTab = tab
                $0.destination = cover
            }

            await store.send(.destination(.dismiss)).finish()

            #expect(events.value == [eventName])
        }
    }

    @Test("알림 목록이 닫히면서 다른 탭으로 옮기면 메인 탭은 알리지 않는다. 새로 그려지는 첫 화면의 onAppear가 남긴다")
    func fullScreenCoverDismissed_withTabChange_doesNotNotifyFirstScreen() async {
        let events = LockIsolated<[String]>([])
        let store = makeStore(events: events) {
            $0.selectedTab = .pose
            $0.destination = .notificationList(PushNotificationListFeature.State())
        }

        await store.send(.route(.archive)).finish()

        #expect(store.selectedTab == .archive)
        #expect(store.destination == nil)
        #expect(events.value.isEmpty)
    }

    @Test("하위 화면 위에서 열린 알림 목록이 닫히며 첫 화면으로 돌아가면 메인 탭은 알리지 않는다. 다시 그려지는 첫 화면의 onAppear가 남긴다")
    func fullScreenCoverDismissed_withPopToFirstScreen_doesNotNotifyFirstScreen() async {
        let events = LockIsolated<[String]>([])
        let store = makeStore(events: events) {
            $0.selectedTab = .pose
            $0.pose.path.append(.randomPose(RandomPoseCarouselFeature.State(peopleCount: .solo)))
            $0.destination = .notificationList(PushNotificationListFeature.State())
        }

        await store.send(.route(.pose)).finish()

        #expect(store.pose.path.isEmpty)
        #expect(events.value.isEmpty)
    }

    @Test("하위 화면이 보이는 채로 알림 목록이 닫히면 첫 화면의 진입 이벤트를 남기지 않는다")
    func fullScreenCoverDismissed_overSubScreen_doesNotLogFirstScreen() async {
        let events = LockIsolated<[String]>([])
        let store = makeStore(events: events) {
            $0.selectedTab = .pose
            $0.pose.path.append(.randomPose(RandomPoseCarouselFeature.State(peopleCount: .solo)))
            $0.destination = .notificationList(PushNotificationListFeature.State())
        }

        await store.send(.destination(.dismiss)).finish()

        #expect(store.pose.path.count == 1)
        #expect(events.value.isEmpty)
    }

    @Test("첫 화면이 다른 화면에 가려진 채 메인 탭이 나타나면 알림 안내를 판단하지 않는다")
    func onAppear_firstScreenCovered_skipsNotificationGuide() async {
        let checks = LockIsolated(0)
        let store = makeStore {
            $0.$userSessionStatus.withLock { $0 = .signedIn(Self.user) }
            $0.destination = .qrScan(QRCodeScanFeature.State(user: Self.user))
        } dependencies: {
            $0.pushNotificationClient.checkAuthorizationStatus = {
                checks.withValue { $0 += 1 }
                return .notDetermined
            }
        }

        let onAppear = store.send(.onAppear)
        // 띄워 둔 화면은 닫힐 때까지 끝나지 않는 표시 효과를 남기므로, 닫은 뒤 효과가 모두 끝나기를 기다립니다.
        await store.send(.destination(.dismiss)).finish()
        await onAppear.finish()

        #expect(checks.value == 0)
        #expect(store.notificationGuide.hasStarted)
    }

    @Test("메인 탭이 나타나면 알림 안내가 알림 권한을 확인해 상태에 맞는 모달을 띄운다")
    func onAppear_presentsNotificationGuideModal() async {
        let store = makeStore {
            $0.$userSessionStatus.withLock { $0 = .signedIn(Self.user) }
        } dependencies: {
            $0.pushNotificationClient.checkAuthorizationStatus = { .notDetermined }
            $0.appVersionClient.currentVersion = { AppVersion(value: "1.4.1") }
            $0.date.now = Date(timeIntervalSince1970: 1_794_272_400)
        }

        await store.send(.onAppear).finish()

        #expect(store.notificationGuide.modal == .consentAndEnable)
    }

    @Test("알림 안내가 보낸 토스트를 메인 탭 토스트로 띄운다")
    func notificationGuideToast_showsMainTabToast() async {
        let store = makeStore()
        let toast = NekiToastItem("11.10 이벤트·혜택 알림에 동의했어요.", style: .success)

        await store.send(.notificationGuide(.delegate(.showToast(toast)))).finish()

        #expect(store.toast == toast)
    }

    @Test("앱이 다시 활성화되면 알림 안내에 전해 설정에서 돌아온 것을 마무리한다")
    func sceneDidBecomeActive_forwardsToNotificationGuide() async {
        let store = makeStore { $0.notificationGuide.isAwaitingSettingsReturn = true }

        await store.send(.sceneDidBecomeActive).finish()

        #expect(store.notificationGuide.isAwaitingSettingsReturn == false)
    }
}


// MARK: - Helpers

private extension MainTabCoordinatorTests {
    /// 지도에 `강남` 검색 결과를 반영해 둔 메인 탭 스토어입니다. 보낸 분석 이벤트의 이름은 `events`에 차례로 모읍니다.
    ///
    /// `MainTabCoordinator.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    func makeStore(
        events: LockIsolated<[String]> = .init([]),
        update: (inout MainTabCoordinator.State) -> Void = { _ in },
        dependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> StoreOf<MainTabCoordinator> {
        var state = MainTabCoordinator.State()
        state.map.root.appliedSearchQuery = PhotoBoothSearchQuery(rawValue: "강남")
        update(&state)

        return Store(initialState: state) {
            MainTabCoordinator()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                events.withValue { $0.append(event.name.value) }
            }
            dependencies(&$0)
        }
    }

    /// 필수 약관에 모두 동의한 테스트 사용자입니다.
    static let user = User(
        id: 900_002,
        nickname: "테스트",
        email: nil,
        profileImageURL: nil,
        providerType: .test,
        allRequiredTermsAgreed: true
    )
}
