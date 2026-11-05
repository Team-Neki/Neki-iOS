//
//  RandomPoseCarouselFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct RandomPoseCarouselFeatureTests {
    @Test("좌우로 넘기면 요청에 성공해 실제로 넘어간 경우만 스와이프 수로 센다")
    func tapLeftAndRight_countsOnlySucceededSwipes() async {
        let nextPose = makePose(id: 2)
        let store = makeStore {
            $0.poseClient.startRandomPoseSuggestion = { direction in
                guard case .right = direction else { throw RandomPoseFailure() }
                return nextPose
            }
        }

        await store.send(.tapRight).finish()
        await store.send(.tapLeft).finish()

        #expect(store.totalSwipeCount == 1)
        #expect(store.currentPose == nextPose)
    }

    @Test("닫기 버튼은 화면만 닫고, 랜덤 포즈 종료는 화면이 스택에서 빠질 때 코디네이터가 남기도록 직접 보내지 않는다")
    func onTapClose_dismissesWithoutLoggingSessionEnd() async {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let isDismissed = LockIsolated(false)
        let store = makeStore(events: events) {
            $0.poseClient.stopRandomPoseSuggestion = {}
            $0.dismiss = DismissEffect { isDismissed.setValue(true) }
        }

        await store.send(.onTapClose).finish()

        #expect(isDismissed.value)
        #expect(events.value.isEmpty)
    }

    @Test("북마크 아이콘을 누르면 요청에 실패해도 북마크를 남긴다")
    func onTapScrap_whenRequestFails_logsBookmark() async {
        var state = RandomPoseCarouselFeature.State(peopleCount: .solo)
        state.currentPose = makePose(id: 1)
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events) {
            $0.poseClient.scrapPose = { _ in throw RandomPoseFailure() }
        }

        await store.send(.onTapScrap).finish()

        #expect(events.value == [.poseBookmark])
    }
}


// MARK: - Helpers

private extension RandomPoseCarouselFeatureTests {
    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다.
    ///
    /// `RandomPoseCarouselFeature.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    func makeStore(
        initialState: RandomPoseCarouselFeature.State = .init(peopleCount: .solo),
        events: LockIsolated<[PoseAnalyticsEvent]> = .init([]),
        dependencies updateDependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> StoreOf<RandomPoseCarouselFeature> {
        Store(initialState: initialState) {
            RandomPoseCarouselFeature()
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
