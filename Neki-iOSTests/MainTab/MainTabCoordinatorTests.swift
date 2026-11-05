//
//  MainTabCoordinatorTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/15/26.
//

import ComposableArchitecture
import Foundation
import Testing
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
}


// MARK: - Helpers

private extension MainTabCoordinatorTests {
    /// 지도에 `강남` 검색 결과를 반영해 둔 메인 탭 스토어입니다. 보낸 분석 이벤트의 이름은 `events`에 차례로 모읍니다.
    ///
    /// `MainTabCoordinator.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    func makeStore(
        events: LockIsolated<[String]> = .init([]),
        update: (inout MainTabCoordinator.State) -> Void = { _ in }
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
        }
    }
}
