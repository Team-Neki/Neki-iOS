//
//  PoseCoordinatorTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct PoseCoordinatorTests {
    @Test("랜덤 포즈 화면이 스택에서 빠지면 요청에 성공한 넘김 수로 랜덤 포즈 종료를 한 번 남긴다")
    func popFrom_randomPose_logsSessionEndWithSucceededSwipes() async throws {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let nextPose = makePose(id: 2)
        let store = makeStore(events: events) {
            $0.poseClient.startRandomPoseSuggestion = { direction in
                guard case .right = direction else { throw RandomPoseFailure() }
                return nextPose
            }
            $0.poseClient.stopRandomPoseSuggestion = {}
        }
        store.send(.root(.delegate(.didTapStartRandomPose(.solo))))
        let randomPoseID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: randomPoseID, action: .randomPose(.tapRight)))).finish()
        await store.send(.path(.element(id: randomPoseID, action: .randomPose(.tapRight)))).finish()
        await store.send(.path(.element(id: randomPoseID, action: .randomPose(.tapLeft)))).finish()

        await store.send(.path(.popFrom(id: randomPoseID))).finish()

        #expect(store.path.isEmpty)
        #expect(events.value == [.randomPoseSuggestionStart, .randomPoseSuggestionEnd(totalSwipeCount: 2)])
    }

    @Test("포즈 상세만 스택에서 빠지면 랜덤 포즈 종료를 남기지 않는다")
    func popFrom_poseDetail_doesNotLogSessionEnd() async throws {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(events: events)
        store.send(.root(.delegate(.didTapImage(makePose(id: 1)))))
        let detailID = try #require(store.path.ids.last)

        await store.send(.path(.popFrom(id: detailID))).finish()

        #expect(store.path.isEmpty)
        #expect(events.value.isEmpty)
    }

    @Test("인원을 고르고 시작하면 랜덤 포즈 화면을 띄울 때 랜덤 포즈 시작을 한 번만 남긴다")
    func startRandomPoseCarousel_logsStartOnceWhenOpeningScreen() async throws {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(events: events) {
            $0.poseClient.stopRandomPoseSuggestion = {}
        }

        store.send(.root(.onTapStartRandomPoseCarousel))
        let randomPoseID = try #require(store.path.ids.last)
        #expect(store.path[id: randomPoseID]?.randomPose != nil)
        await store.send(.path(.popFrom(id: randomPoseID))).finish()

        #expect(events.value == [.randomPoseSuggestionStart, .randomPoseSuggestionEnd(totalSwipeCount: 0)])
    }

    @Test(
        "닫기 버튼이나 뒤로 스와이프로 랜덤 포즈 화면을 벗어나면 미리 불러온 랜덤 포즈를 한 번 비운다",
        arguments: [true, false]
    )
    func leavingRandomPose_flushesRandomPoseBufferOnce(byCloseButton: Bool) async throws {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let flushCount = LockIsolated(0)
        let store = makeStore(events: events) {
            $0.poseClient.stopRandomPoseSuggestion = { flushCount.withValue { $0 += 1 } }
        }
        let openTask = store.send(.root(.delegate(.didTapStartRandomPose(.solo))))
        let randomPoseID = try #require(store.path.ids.last)

        if byCloseButton {
            await store.send(.path(.element(id: randomPoseID, action: .randomPose(.onTapClose)))).finish()
        } else {
            // 뒤로 스와이프하면 내비게이션 스택이 바로 popFrom을 보냅니다.
            await store.send(.path(.popFrom(id: randomPoseID))).finish()
        }
        // 닫기 버튼의 dismiss가 보낸 popFrom은 화면을 띄울 때 시작한 효과에서 처리되므로, 그 효과가 끝날 때까지 기다립니다.
        await openTask.finish()

        #expect(store.path.isEmpty)
        #expect(flushCount.value == 1)
        #expect(events.value == [.randomPoseSuggestionStart, .randomPoseSuggestionEnd(totalSwipeCount: 0)])
    }
}


// MARK: - Helpers

private extension PoseCoordinatorTests {
    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다.
    ///
    /// `PoseCoordinator.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    func makeStore(
        events: LockIsolated<[PoseAnalyticsEvent]>,
        dependencies updateDependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> StoreOf<PoseCoordinator> {
        Store(initialState: PoseCoordinator.State()) {
            PoseCoordinator()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? PoseAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            updateDependencies(&$0)
        }
    }

    func makePose(id: PoseID) -> Pose {
        Pose(
            id: id,
            peopleCountOption: .solo,
            imageURL: nil,
            isScrapped: false,
            contentType: .jpeg,
            width: nil,
            height: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private struct RandomPoseFailure: Error {}
