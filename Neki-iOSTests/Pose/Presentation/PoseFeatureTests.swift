//
//  PoseFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct PoseFeatureTests {
    @Test("포즈 목록에서 카드를 누르면 포즈 ID와 카드의 인원 수, 목록 진입점으로 상세 클릭을 남긴다")
    func imageTapped_inList_logsPoseDetailClickFromList() async {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(events: events)

        await store.send(.imageTapped(makePose(id: 128, peopleCount: .duo)))
        await store.finish()

        #expect(events.value == [.poseDetailClick(poseID: 128, peopleCount: 2, entryPoint: .list)])
    }

    @Test("북마크 목록에서 카드를 누르면 북마크 진입점으로 남기고, 5인 이상 포즈는 인원 수를 5로 보낸다")
    func imageTapped_inBookmarkList_logsPoseDetailClickFromBookmark() async {
        var state = PoseFeature.State()
        state.isSelectedScrap = true
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events)

        await store.send(.imageTapped(makePose(id: 7, peopleCount: .overQuartet)))
        await store.finish()

        #expect(events.value == [.poseDetailClick(poseID: 7, peopleCount: 5, entryPoint: .bookmark)])
    }

    @Test("카드의 북마크 버튼을 누르면 상세 클릭을 남기지 않는다")
    func onTapBookmark_doesNotLogPoseDetailClick() async {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(events: events)

        await store.send(.onTapBookmark(makePose(id: 128, peopleCount: .duo)))
        await store.finish()

        #expect(events.value == [.poseBookmark])
    }

    @Test("포즈 첫 화면이 보일 때마다 목록을 이미 불러왔어도 화면 진입을 남긴다")
    func onAppear_whenPosesLoaded_logsPoseViewEveryTime() async {
        var state = PoseFeature.State()
        state.generalPoses = [makePose(id: 1, peopleCount: .solo)]
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events)

        await store.send(.onAppear)
        await store.send(.onAppear)
        await store.finish()

        #expect(events.value == [.poseView, .poseView])
    }

    @Test("상세 클릭은 포즈 ID를 문자열로 `pose_id`에 담는다")
    func poseDetailClick_sendsPoseIDAsString() {
        let parameters = PoseAnalyticsEvent.poseDetailClick(poseID: 128, peopleCount: 2, entryPoint: .list).parameters

        #expect(PoseAnalyticsEvent.poseDetailClick(poseID: 128, peopleCount: 2, entryPoint: .list).name.value == "pose_detail_click")
        #expect(AnalyticsParameterKey.poseId.name == "pose_id")
        guard case let .string(poseID) = parameters?[.poseId],
              case let .integer(peopleCount) = parameters?[.peopleCount],
              case let .string(entryPoint) = parameters?[.entryPoint] else {
            Issue.record("상세 클릭 속성의 값 형식이 다릅니다: \(String(describing: parameters))")
            return
        }
        #expect(poseID == "128")
        #expect(peopleCount == 2)
        #expect(entryPoint == "list")
    }
}


// MARK: - Helpers

private extension PoseFeatureTests {
    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다. 이펙트가 보내는 액션은 확인하지 않습니다.
    func makeStore(
        initialState: PoseFeature.State = .init(),
        events: LockIsolated<[PoseAnalyticsEvent]> = .init([])
    ) -> TestStoreOf<PoseFeature> {
        let store = TestStore(initialState: initialState) {
            PoseFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? PoseAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            $0.poseClient.scrapPose = { _ in }
        }
        store.exhaustivity = .off
        return store
    }

    func makePose(id: PoseID, peopleCount: PeopleCountOption) -> Pose {
        Pose(
            id: id,
            peopleCountOption: peopleCount,
            imageURL: nil,
            isScrapped: false,
            contentType: .jpeg,
            width: nil,
            height: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
