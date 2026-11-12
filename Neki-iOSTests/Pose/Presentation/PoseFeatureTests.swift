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

    @Test("북마크 아이콘을 누르면 요청에 실패해도 북마크를 남긴다")
    func onTapBookmark_whenRequestFails_logsBookmark() async {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(events: events) {
            $0.poseClient.scrapPose = { _ in throw BookmarkFailure() }
        }

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

    @Test("관계 태그를 고르면 2인 포즈만 보이고, 마지막으로 보이는 포즈와 개수도 2인 기준이다")
    func onTapRelationFilter_showsDuoPosesOnly() async {
        var state = PoseFeature.State()
        state.generalPoses = [
            makePose(id: 1, peopleCount: .solo),
            makePose(id: 2, peopleCount: .duo),
            makePose(id: 3, peopleCount: .trio),
            makePose(id: 4, peopleCount: .duo),
            makePose(id: 5, peopleCount: .solo)
        ]
        let store = makeStore(initialState: state)

        await store.send(.onTapRelationFilter(.friend))

        #expect(store.state.visiblePoses.map(\.id) == [2, 4])
        #expect(store.state.lastVisiblePoseID == 4)
        #expect(store.state.displayedPoseCount == 2)
    }

    @Test("3인을 고른 상태에서 친구를 고르면 인원수가 바뀌어 맨 위로 이동 신호가 오른다")
    func onTapRelationFilter_whenPeopleCountChanges_bumpsScrollGeneration() async {
        var state = PoseFeature.State()
        state.selectedCountFilterOption = .trio
        let store = makeStore(initialState: state)

        await store.send(.onTapRelationFilter(.friend))

        #expect(store.state.scrollToTopGeneration == 1)
    }

    @Test("2인이 그대로인 관계 선택·변경·해제는 맨 위로 이동 신호를 올리지 않는다")
    func onTapRelationFilter_whenDuoStays_keepsScrollGeneration() async {
        var state = PoseFeature.State()
        state.selectedCountFilterOption = .duo
        let store = makeStore(initialState: state)

        await store.send(.onTapRelationFilter(.friend))
        await store.send(.onTapRelationFilter(.couple))
        await store.send(.onTapRelationFilter(.couple))

        #expect(store.state.scrollToTopGeneration == .zero)
    }

    @Test("인원수 선택과 북마크 전환은 누를 때마다 맨 위로 이동 신호를 올린다")
    func peopleCountAndBookmark_bumpScrollGenerationEveryTime() async {
        var state = PoseFeature.State()
        state.generalPoses = [makePose(id: 1, peopleCount: .duo)]
        state.scrappedPoses = [makePose(id: 2, peopleCount: .solo)]
        let store = makeStore(initialState: state)

        await store.send(.selectPeopleCount(.trio))
        await store.send(.selectPeopleCount(.trio))
        await store.send(.onTapScrapMode)
        await store.send(.onTapScrapMode)
        await store.finish()

        #expect(store.state.scrollToTopGeneration == 4)
    }

    @Test("관계 태그로 2인이 자동 선택돼도 이벤트를 남기지 않는다")
    func onTapRelationFilter_logsNothing() async {
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(events: events)

        await store.send(.onTapRelationFilter(.friend))
        await store.finish()

        #expect(events.value.isEmpty)
    }

    @Test("관계를 고른 상태에서 시트로 3인을 고르면 3인 필터 이벤트를 남긴다")
    func selectTrio_whileRelation_logsPoseFilterToggle() async {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events)

        await store.send(.selectPeopleCount(.trio))
        await store.finish()

        #expect(events.value == [.poseFilterToggle(peopleCount: 3)])
        #expect(store.state.selectedRelationFilterOption == nil)
    }

    @Test("관계를 고른 상태에서 2인을 해제하면 이벤트를 남기지 않는다")
    func deselectDuo_whileRelation_logsNothing() async {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.couple)
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events)

        await store.send(.selectPeopleCount(.duo))
        await store.finish()

        #expect(events.value.isEmpty)
    }

    @Test("관계를 고른 상태에서 북마크를 누르면 북마크 필터 이벤트만 남긴다")
    func onTapScrapMode_whileRelation_logsBookmarkFilterOnly() async {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.crush)
        let events = LockIsolated<[PoseAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events)

        await store.send(.onTapScrapMode)
        await store.finish()

        #expect(events.value == [.poseBookmarkFilter])
    }

    @Test("정렬 메뉴가 꺼져 있으면 정렬 라벨을 눌러도 메뉴가 열리지 않는다", .enabled(if: PoseFeature.State.isSortMenuEnabled == false))
    func onTapSortMenu_whenDisabled_keepsMenuClosed() async {
        let store = makeStore()

        await store.send(.onTapSortMenu)

        #expect(store.state.isSortMenuPresented == false)
    }

    @Test("정렬 기준을 고르면 기준이 바뀌고 메뉴가 닫힌다")
    func selectSortOption_updatesOptionAndClosesMenu() async {
        var state = PoseFeature.State()
        state.isSortMenuPresented = true
        let store = makeStore(initialState: state)

        await store.send(.selectSortOption(.popular))

        #expect(store.state.selectedSortOption == .popular)
        #expect(store.state.isSortMenuPresented == false)
    }
}


// MARK: - Helpers

private extension PoseFeatureTests {
    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다. 이펙트가 보내는 액션은 확인하지 않습니다.
    /// 목록 조회는 서버를 부르지 않고 빈 목록을 돌려줍니다.
    func makeStore(
        initialState: PoseFeature.State = .init(),
        events: LockIsolated<[PoseAnalyticsEvent]> = .init([]),
        dependencies updateDependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<PoseFeature> {
        let store = TestStore(initialState: initialState) {
            PoseFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? PoseAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            $0.poseClient.scrapPose = { _ in }
            $0.poseClient.fetchPoseList = { _, _, _ in ([], false) }
            $0.poseClient.fetchScrappedPoseList = { _, _, _ in ([], false) }
            updateDependencies(&$0)
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
            height: nil
        )
    }
}

private struct BookmarkFailure: Error {}
