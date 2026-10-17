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
}


// MARK: - Helpers

private extension MainTabCoordinatorTests {
    /// 지도에 `강남` 검색 결과를 반영해 둔 메인 탭 스토어입니다.
    ///
    /// `MainTabCoordinator.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    func makeStore() -> StoreOf<MainTabCoordinator> {
        var state = MainTabCoordinator.State()
        state.map.root.appliedSearchQuery = PhotoBoothSearchQuery(rawValue: "강남")

        return Store(initialState: state) {
            MainTabCoordinator()
        } withDependencies: {
            $0.analyticsClient.logEvent = { _ in }
        }
    }
}
