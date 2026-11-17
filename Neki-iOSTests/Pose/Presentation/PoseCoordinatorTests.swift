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
        let (startCount, otherEvents) = splitStartEvents(events.value)
        #expect(startCount == 1)
        #expect(otherEvents == [.randomPoseSuggestionEnd(totalSwipeCount: 2)])
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

        let (startCount, otherEvents) = splitStartEvents(events.value)
        #expect(startCount == 1)
        #expect(otherEvents == [.randomPoseSuggestionEnd(totalSwipeCount: 0)])
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
        let (startCount, otherEvents) = splitStartEvents(events.value)
        #expect(startCount == 1)
        #expect(otherEvents == [.randomPoseSuggestionEnd(totalSwipeCount: 0)])
    }

    @Test("북마크하지 않은 포즈의 상세를 열고 넘겨도 북마크 개수는 그대로다")
    func poseDetail_fetchingUnbookmarkedPoses_keepsBookmarkCount() async throws {
        let poses = (101...104).map { makePose(id: $0) }
        let posesByID = Dictionary(uniqueKeysWithValues: poses.map { ($0.id, $0) })
        let store = makeStore(events: LockIsolated([]), initialState: makeBookmarkLoadedState(general: poses)) {
            $0.poseClient.fetchPoseDetail = { id in
                guard let pose = posesByID[id] else { throw UnknownPoseFailure() }
                return pose
            }
        }

        store.send(.root(.delegate(.didTapImage(poses[0]))))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()
        for poseID in [102, 103, 104, 101] {
            await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(poseID))))).finish()
        }

        #expect(store.root.scrappedTotalCount == 51)
        #expect(store.root.scrappedPoses.map(\.id) == Array(1...20))
    }

    @Test("받지 않은 뒷페이지에 있는 북마크의 상세를 열어도 북마크 목록과 개수는 그대로다")
    func poseDetail_fetchingUnloadedBookmark_keepsBookmarkList() async throws {
        let laterBookmark = makePose(id: 35, isScrapped: true)
        let store = makeStore(events: LockIsolated([]), initialState: makeBookmarkLoadedState(general: [laterBookmark])) {
            $0.poseClient.fetchPoseDetail = { _ in laterBookmark }
        }

        store.send(.root(.delegate(.didTapImage(laterBookmark))))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()

        #expect(store.root.scrappedTotalCount == 51)
        #expect(store.root.scrappedPoses.map(\.id) == Array(1...20))
    }

    @Test("랜덤 포즈에서 연 상세가 포즈를 받아도 북마크 개수는 그대로다")
    func randomPoseDetail_fetchingPose_keepsBookmarkCount() async throws {
        let randomPose = makePose(id: 500)
        let store = makeStore(events: LockIsolated([]), initialState: makeBookmarkLoadedState(general: [])) {
            $0.poseClient.fetchPoseDetail = { _ in randomPose }
        }

        store.send(.root(.delegate(.didTapStartRandomPose(.solo))))
        // 랜덤 포즈 화면의 상세 버튼이 보내는 화면 전환입니다. 화면을 띄우는 액션의 효과는 화면이 닫힐 때까지 끝나지 않아 기다리지 않습니다.
        store.send(.routeToDetail(randomPose))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()

        #expect(store.root.scrappedTotalCount == 51)
        #expect(store.root.scrappedPoses.map(\.id) == Array(1...20))
    }

    @Test("북마크 탭에서 연 상세에서 북마크를 해제하고 넘겼다 돌아와도 북마크 개수는 하나만 준다")
    func bookmarkDetail_unbookmarkingThenRevisiting_decrementsBookmarkCountOnce() async throws {
        let bookmarkedPoses = Dictionary(uniqueKeysWithValues: (1...20).map { ($0, makePose(id: $0, isScrapped: true)) })
        let unbookmarkedPose = makePose(id: 5)
        let isServerBookmarked = LockIsolated(true)
        let store = makeStore(events: LockIsolated([]), initialState: makeBookmarkLoadedState(general: [], isBookmarkTab: true)) {
            $0.poseClient.scrapPose = { _ in isServerBookmarked.setValue(false) }
            $0.poseClient.fetchPoseDetail = { id in
                if id == unbookmarkedPose.id, isServerBookmarked.value == false { return unbookmarkedPose }
                guard let pose = bookmarkedPoses[id] else { throw UnknownPoseFailure() }
                return pose
            }
        }

        let pose = try #require(store.root.scrappedPoses[id: 5])
        store.send(.root(.delegate(.didTapImage(pose))))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()
        await store.send(.path(.element(id: detailID, action: .detail(.onTapScrap)))).finish()
        await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(6))))).finish()
        await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(5))))).finish()

        #expect(store.root.scrappedTotalCount == 50)
        #expect(store.root.scrappedPoses[id: 5] == nil)
    }

    @Test("상세에서 하트로 북마크하면 북마크 목록 맨 앞에 넣고 개수가 하나 는다")
    func poseDetail_bookmarking_insertsAtTopAndIncrementsCount() async throws {
        let pose = makePose(id: 101)
        let store = makeStore(events: LockIsolated([]), initialState: makeBookmarkLoadedState(general: [pose])) {
            $0.poseClient.fetchPoseDetail = { _ in pose }
            $0.poseClient.scrapPose = { _ in }
        }

        store.send(.root(.delegate(.didTapImage(pose))))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()
        await store.send(.path(.element(id: detailID, action: .detail(.onTapScrap)))).finish()

        #expect(store.root.scrappedTotalCount == 52)
        #expect(store.root.scrappedPoses.first?.id == 101)
        #expect(store.root.generalPoses[id: 101]?.isScrapped == true)
    }

    @Test("그리드에서 연 상세를 끝까지 넘기면 다음 페이지를 받아 이어 넘기고, 마지막 페이지 뒤로는 더 받지 않는다")
    func gridDetail_swipingToEnd_loadsNextPages() async throws {
        let poses = (1...45).map { makePose(id: $0) }
        let posesByID = Dictionary(uniqueKeysWithValues: poses.map { ($0.id, $0) })
        let requestedPages = LockIsolated<[Int]>([])
        let store = makeStore(events: LockIsolated([]), initialState: makeFirstPageLoadedState(makeListPage(poses, page: 0, size: 20), isBookmarkTab: false)) {
            $0.poseClient.fetchPoseDetail = { id in
                guard let pose = posesByID[id] else { throw UnknownPoseFailure() }
                return pose
            }
            $0.poseClient.fetchPoseList = { page, size, _, _ in
                requestedPages.withValue { $0.append(page) }
                return makeListPage(poses, page: page, size: size)
            }
        }

        store.send(.root(.delegate(.didTapImage(poses[0]))))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()
        await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(5))))).finish()

        #expect(requestedPages.value.isEmpty)

        await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(20))))).finish()

        #expect(requestedPages.value == [1])
        #expect(store.path[id: detailID]?.detail?.poses.map(\.id) == Array(1...40))

        await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(40))))).finish()
        await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(45))))).finish()

        #expect(requestedPages.value == [1, 2])
        #expect(store.path[id: detailID]?.detail?.poses.map(\.id) == Array(1...45))
    }

    @Test("끝 가까이에 있는 포즈의 상세를 열면 바로 다음 페이지를 받는다")
    func gridDetail_openedNearEnd_loadsNextPage() async throws {
        let poses = (1...45).map { makePose(id: $0) }
        let posesByID = Dictionary(uniqueKeysWithValues: poses.map { ($0.id, $0) })
        let requestedPages = LockIsolated<[Int]>([])
        let store = makeStore(events: LockIsolated([]), initialState: makeFirstPageLoadedState(makeListPage(poses, page: 0, size: 20), isBookmarkTab: false)) {
            $0.poseClient.fetchPoseDetail = { id in
                guard let pose = posesByID[id] else { throw UnknownPoseFailure() }
                return pose
            }
            $0.poseClient.fetchPoseList = { page, size, _, _ in
                requestedPages.withValue { $0.append(page) }
                return makeListPage(poses, page: page, size: size)
            }
        }

        store.send(.root(.delegate(.didTapImage(poses[19]))))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()

        #expect(requestedPages.value == [1])
        #expect(store.path[id: detailID]?.detail?.poses.map(\.id) == Array(1...40))
        #expect(store.path[id: detailID]?.detail?.selectedID == 20)
    }

    @Test("북마크 탭에서 연 상세에서 북마크를 해제하고 끝까지 넘겨도 빠지거나 겹치는 포즈가 없다")
    func bookmarkDetail_unbookmarkingThenSwipingToEnd_keepsListComplete() async throws {
        let server = OffsetBookmarkServer(ids: Array(1...45))
        let store = makeStore(events: LockIsolated([]), initialState: makeFirstPageLoadedState(server.page(0, size: 20), isBookmarkTab: true)) {
            $0.poseClient.scrapPose = { server.toggle($0) }
            $0.poseClient.fetchPoseDetail = { id in
                Pose(id: id, peopleCountOption: .solo, imageURL: nil, isScrapped: server.ids.value.contains(id), contentType: .jpeg, width: nil, height: nil)
            }
            $0.poseClient.fetchScrappedPoseList = { page, size, _ in server.page(page, size: size) }
        }

        let firstPose = try #require(store.root.scrappedPoses.first)
        store.send(.root(.delegate(.didTapImage(firstPose))))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()
        // 3·7번째 포즈의 북마크를 해제하면 서버에서는 뒤 포즈가 앞 페이지 자리로 당겨집니다.
        for poseID in [3, 7] {
            await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(poseID))))).finish()
            await store.send(.path(.element(id: detailID, action: .detail(.onTapScrap)))).finish()
        }
        for poseID in [20, 42, 45] {
            await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(poseID))))).finish()
        }

        // 상세는 해제한 포즈도 제자리에 두고, 서버 목록의 나머지 포즈를 한 번씩 이어 붙입니다.
        #expect(store.path[id: detailID]?.detail?.poses.map(\.id) == Array(1...45))
        #expect(store.root.scrappedPoses.map(\.id) == server.ids.value)
    }

    @Test("랜덤 포즈에서 연 상세는 끝에 와도 다음 페이지를 받지 않는다")
    func randomPoseDetail_nearEnd_doesNotLoadNextPage() async throws {
        let poses = (1...45).map { makePose(id: $0) }
        let randomPose = makePose(id: 500)
        let posesByID = Dictionary(uniqueKeysWithValues: (poses + [randomPose]).map { ($0.id, $0) })
        let requestedPages = LockIsolated<[Int]>([])
        let store = makeStore(events: LockIsolated([]), initialState: makeFirstPageLoadedState(makeListPage(poses, page: 0, size: 20), isBookmarkTab: false)) {
            $0.poseClient.fetchPoseDetail = { id in
                guard let pose = posesByID[id] else { throw UnknownPoseFailure() }
                return pose
            }
            $0.poseClient.fetchPoseList = { page, size, _, _ in
                requestedPages.withValue { $0.append(page) }
                return makeListPage(poses, page: page, size: size)
            }
        }

        // 랜덤 포즈 화면의 상세 버튼이 보내는 화면 전환입니다. 화면을 띄우는 액션의 효과는 화면이 닫힐 때까지 끝나지 않아 기다리지 않습니다.
        store.send(.routeToDetail(randomPose))
        let detailID = try #require(store.path.ids.last)
        await store.send(.path(.element(id: detailID, action: .detail(.onAppear)))).finish()
        await store.send(.path(.element(id: detailID, action: .detail(.pageChanged(20))))).finish()

        #expect(requestedPages.value.isEmpty)
        #expect(store.path[id: detailID]?.detail?.poses.map(\.id) == Array(1...20) + [500])
    }
}


// MARK: - Helpers

private extension PoseCoordinatorTests {
    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다.
    ///
    /// `PoseCoordinator.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    func makeStore(
        events: LockIsolated<[PoseAnalyticsEvent]>,
        initialState: PoseCoordinator.State = PoseCoordinator.State(),
        dependencies updateDependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> StoreOf<PoseCoordinator> {
        Store(initialState: initialState) {
            PoseCoordinator()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? PoseAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            updateDependencies(&$0)
        }
    }

    /// 랜덤 포즈 시작 수와 그 밖의 이벤트로 나눕니다.
    ///
    /// 시작은 화면을 띄우는 액션의 효과가, 종료는 화면을 빼는 액션의 효과가 따로 남겨 둘 사이의 기록 순서는 보장되지 않습니다.
    func splitStartEvents(_ events: [PoseAnalyticsEvent]) -> (startCount: Int, others: [PoseAnalyticsEvent]) {
        let startCount = events.filter { $0 == .randomPoseSuggestionStart }.count
        return (startCount, events.filter { $0 != .randomPoseSuggestionStart })
    }

    func makePose(id: PoseID, isScrapped: Bool = false) -> Pose {
        Pose(
            id: id,
            peopleCountOption: .solo,
            imageURL: nil,
            isScrapped: isScrapped,
            contentType: .jpeg,
            width: nil,
            height: nil
        )
    }

    /// 북마크 51개 중 앞 20개(1~20)를 받은 포즈 화면입니다.
    ///
    /// 전체 탭에는 `general`이 전부 보이고(다음 페이지 없음), `isBookmarkTab`이면 북마크 탭을 보고 있습니다.
    func makeBookmarkLoadedState(general: [Pose], isBookmarkTab: Bool = false) -> PoseCoordinator.State {
        var state = PoseCoordinator.State()
        state.root.generalPoses = IdentifiedArray(uniqueElements: general)
        state.root.loadedGeneralFilter = PoseListFilter()
        state.root.isLastGeneralPage = true
        state.root.scrappedPoses = IdentifiedArray(uniqueElements: (1...20).map { makePose(id: $0, isScrapped: true) })
        state.root.scrappedTotalCount = 51
        state.root.isScrappedListLoaded = true
        state.root.isSelectedScrap = isBookmarkTab
        state.root.visiblePoses = isBookmarkTab ? state.root.scrappedPoses.elements : general
        return state
    }

    /// 서버 목록의 첫 페이지만 받은 포즈 화면입니다. `isBookmarkTab`이면 북마크 탭, 아니면 전체 탭의 목록입니다.
    func makeFirstPageLoadedState(_ firstPage: PoseListPage, isBookmarkTab: Bool) -> PoseCoordinator.State {
        var state = PoseCoordinator.State()
        if isBookmarkTab {
            state.root.isSelectedScrap = true
            state.root.scrappedPoses = IdentifiedArray(uniqueElements: firstPage.poses)
            state.root.scrappedTotalCount = firstPage.totalCount
            state.root.isScrappedListLoaded = true
            state.root.scrappedPage = 1
            state.root.isLastScrappedPage = firstPage.hasNext == false
        } else {
            state.root.generalPoses = IdentifiedArray(uniqueElements: firstPage.poses)
            state.root.loadedGeneralFilter = PoseListFilter()
            state.root.requestedGeneralFilter = PoseListFilter()
            state.root.generalTotalCount = firstPage.totalCount
            state.root.generalPage = 1
            state.root.isLastGeneralPage = firstPage.hasNext == false
        }
        state.root.visiblePoses = firstPage.poses
        return state
    }
}

/// `poses`를 서버처럼 자리로 잘라 `page`번째 페이지를 만듭니다.
private func makeListPage(_ poses: [Pose], page: Int, size: Int) -> PoseListPage {
    let start = min(page * size, poses.count)
    let end = min(start + size, poses.count)
    return PoseListPage(poses: Array(poses[start..<end]), hasNext: end < poses.count, totalCount: poses.count)
}

private struct RandomPoseFailure: Error {}

private struct UnknownPoseFailure: Error {}
