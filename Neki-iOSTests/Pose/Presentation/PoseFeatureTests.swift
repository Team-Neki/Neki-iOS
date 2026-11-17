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
        state.loadedGeneralFilter = PoseListFilter()
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

    @Test("관계 태그를 고르면 새 목록이 오기 전에는 받아 둔 목록에서 그 관계의 2인 포즈만 먼저 보이고 개수는 숨긴다")
    func onTapRelationFilter_beforeResponse_showsMatchingLoadedPoses() async {
        var state = PoseFeature.State()
        state.generalPoses = [
            makePose(id: 1, peopleCount: .solo),
            makePose(id: 2, peopleCount: .duo, relation: .friend),
            makePose(id: 3, peopleCount: .duo),
            makePose(id: 4, peopleCount: .duo, relation: .friend),
            makePose(id: 5, peopleCount: .duo, relation: .couple)
        ]
        state.loadedGeneralFilter = PoseListFilter()
        state.generalTotalCount = 5
        let (gate, openGate) = AsyncStream<Void>.makeStream()
        let store = makeStore(initialState: state) {
            $0.poseClient.fetchPoseList = { _, _, _, _ in
                for await _ in gate { break }
                return PoseListPage(poses: [], hasNext: false, totalCount: .zero)
            }
        }

        await store.send(.onTapRelationFilter(.friend))

        #expect(store.state.visiblePoses.map(\.id) == [2, 4])
        #expect(store.state.paginationTriggerPoseIDs == [2, 4])
        #expect(store.state.displayedPoseCount == nil)
        openGate.yield()
        openGate.finish()
        await store.finish()
    }

    @Test("관계 태그를 고르면 2인과 그 관계로 첫 페이지를 받아, 받은 목록과 서버 전체 개수를 보여 준다")
    func onTapRelationFilter_fetchesFirstPageWithDuoAndRelation() async {
        let requests = LockIsolated<[ListRequest]>([])
        let friendPoses = [makePose(id: 7, peopleCount: .duo, relation: .friend), makePose(id: 9, peopleCount: .duo, relation: .friend)]
        let store = makeStore {
            $0.poseClient.fetchPoseList = { page, _, filter, refresh in
                requests.withValue { $0.append(ListRequest(page: page, filter: filter, refresh: refresh)) }
                return PoseListPage(poses: friendPoses, hasNext: false, totalCount: 12)
            }
        }

        await store.send(.onTapRelationFilter(.friend))
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value == [ListRequest(page: 0, filter: PoseListFilter(peopleCount: .duo, relation: .friend), refresh: true)])
        #expect(store.state.visiblePoses.map(\.id) == [7, 9])
        #expect(store.state.displayedPoseCount == 12)
    }

    @Test("3인을 고른 상태에서 친구를 고르면 인원수가 바뀌어 맨 위로 이동 신호가 오른다")
    func onTapRelationFilter_whenPeopleCountChanges_bumpsScrollGeneration() async {
        var state = PoseFeature.State()
        state.selectedCountFilterOption = .trio
        let store = makeStore(initialState: state)

        await store.send(.onTapRelationFilter(.friend))

        #expect(store.state.scrollToTopGeneration == 1)
    }

    @Test("2인이 그대로여도 관계를 고르거나 바꾸거나 해제하면 목록이 바뀌어 맨 위로 이동 신호가 오른다")
    func onTapRelationFilter_whenDuoStays_bumpsScrollGeneration() async {
        var state = PoseFeature.State()
        state.selectedCountFilterOption = .duo
        let store = makeStore(initialState: state)

        await store.send(.onTapRelationFilter(.friend))
        await store.send(.onTapRelationFilter(.couple))
        await store.send(.onTapRelationFilter(.couple))
        await store.finish()

        #expect(store.state.scrollToTopGeneration == 3)
    }

    @Test("조건을 바꾼 뒤 늦게 온 이전 조건의 응답은 버린다")
    func fetchListResponse_forPreviousFilter_isIgnored() async {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.couple)
        state.requestedGeneralFilter = PoseListFilter(peopleCount: .duo, relation: .couple)
        state.isGeneralLoading = true
        let store = makeStore(initialState: state)
        let friendPage = PoseListPage(poses: [makePose(id: 1, peopleCount: .duo, relation: .friend)], hasNext: false, totalCount: 1)

        await store.send(.fetchListResponse(.general(PoseListFilter(peopleCount: .duo, relation: .friend)), page: 0, .success(friendPage)))

        #expect(store.state.generalPoses.isEmpty)
        #expect(store.state.loadedGeneralFilter == nil)
        #expect(store.state.isGeneralLoading)
    }

    @Test("받아 둔 조건으로 돌아오면 다른 조건으로 부르던 요청을 취소해, 늦게 온 응답이 목록을 바꾸지 않는다")
    func returningToLoadedFilter_cancelsOtherFilterRequest() async {
        let duoFilter = PoseListFilter(peopleCount: .duo)
        var state = PoseFeature.State()
        state.selectedCountFilterOption = .duo
        state.generalPoses = [makePose(id: 1, peopleCount: .duo), makePose(id: 2, peopleCount: .duo, relation: .couple)]
        state.loadedGeneralFilter = duoFilter
        state.requestedGeneralFilter = duoFilter
        state.generalTotalCount = 157
        state.generalPage = 1
        let friendPage = PoseListPage(poses: [makePose(id: 101, peopleCount: .duo, relation: .friend)], hasNext: false, totalCount: 51)
        let requests = LockIsolated<[ListRequest]>([])
        let (gate, openGate) = AsyncStream<Void>.makeStream()
        let store = makeStore(initialState: state) {
            $0.poseClient.fetchPoseList = { page, _, filter, refresh in
                requests.withValue { $0.append(ListRequest(page: page, filter: filter, refresh: refresh)) }
                guard filter.relation == .friend else { return PoseListPage(poses: [], hasNext: false, totalCount: 157) }
                for await _ in gate { break }
                return friendPage
            }
        }

        // 친구 칩을 빠르게 두 번 누릅니다. 2인+친구 응답은 2인으로 돌아온 뒤에 옵니다.
        await store.send(.onTapRelationFilter(.friend))
        await store.send(.onTapRelationFilter(.friend))
        openGate.yield()
        openGate.finish()
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(store.state.loadedGeneralFilter == duoFilter)
        #expect(store.state.visiblePoses.map(\.id) == [1, 2])
        #expect(store.state.displayedPoseCount == 157)
        #expect(store.state.isGeneralLoading == false)

        await store.send(.loadMoreItems)
        await store.finish()
        #expect(requests.value.last == ListRequest(page: 1, filter: duoFilter, refresh: false))
    }

    @Test("응답에 전체 개수가 없으면 목록은 보여 주고 포즈 개수만 숨긴다")
    func fetchListResponse_withoutTotalCount_hidesCountOnly() async {
        var state = PoseFeature.State()
        state.requestedGeneralFilter = PoseListFilter()
        let store = makeStore(initialState: state)
        let page = PoseListPage(poses: [makePose(id: 1, peopleCount: .solo)], hasNext: false, totalCount: nil)

        await store.send(.fetchListResponse(.general(PoseListFilter()), page: 0, .success(page)))

        #expect(store.state.visiblePoses.map(\.id) == [1])
        #expect(store.state.displayedPoseCount == nil)
    }

    @Test("당겨서 새로고침하면 첫 페이지만 다시 받고, 다음 페이지는 끝 근처 카드가 나타날 때 받는다")
    func onRefresh_fetchesFirstPageOnly_untilLoadMore() async {
        var state = PoseFeature.State()
        state.generalPoses = IdentifiedArray(uniqueElements: (1...60).map { makePose(id: $0, peopleCount: .solo) })
        state.loadedGeneralFilter = PoseListFilter()
        state.requestedGeneralFilter = PoseListFilter()
        state.generalPage = 2
        state.isLastGeneralPage = true
        let requests = LockIsolated<[ListRequest]>([])
        let store = makeStore(initialState: state) {
            $0.poseClient.fetchPoseList = { page, _, filter, refresh in
                requests.withValue { $0.append(ListRequest(page: page, filter: filter, refresh: refresh)) }
                let poses = (1...20).map { 100 + page * 20 + $0 }.map { Pose(id: $0, peopleCountOption: .solo, imageURL: nil, isScrapped: false, contentType: .jpeg, width: nil, height: nil) }
                return PoseListPage(poses: poses, hasNext: page == .zero, totalCount: 40)
            }
        }

        await store.send(.onRefresh)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value == [ListRequest(page: 0, filter: PoseListFilter(), refresh: true)])
        #expect(store.state.generalPoses.map(\.id) == Array(101...120))
        #expect(store.state.isLastGeneralPage == false)

        await store.send(.loadMoreItems)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value == [
            ListRequest(page: 0, filter: PoseListFilter(), refresh: true),
            ListRequest(page: 1, filter: PoseListFilter(), refresh: false)
        ])
        #expect(store.state.generalPoses.map(\.id) == Array(101...140))
        #expect(store.state.isLastGeneralPage)
    }

    @Test("보이는 포즈의 끝 6개가 다음 페이지 신호 카드이고, 조건을 바꾸면 보이는 목록에서 다시 정한다")
    func paginationTriggerPoseIDs_areLastVisiblePoses() async {
        var state = PoseFeature.State()
        state.requestedGeneralFilter = PoseListFilter()
        let store = makeStore(initialState: state)
        let poses = (1...10).map { makePose(id: $0, peopleCount: $0.isMultiple(of: 2) ? .duo : .solo) }

        await store.send(.fetchListResponse(.general(PoseListFilter()), page: 0, .success(PoseListPage(poses: poses, hasNext: true, totalCount: 30))))
        #expect(store.state.paginationTriggerPoseIDs == Set(5...10))

        await store.send(.selectPeopleCount(.duo))
        #expect(store.state.paginationTriggerPoseIDs == [2, 4, 6, 8, 10])
        await store.finish()
    }

    @Test("북마크 목록을 받기 전에 하트를 눌러도, 북마크 칩을 누르면 서버에서 북마크 목록을 받는다")
    func onTapScrapMode_afterBookmarkingBeforeLoad_fetchesScrappedList() async {
        let tappedPose = makePose(id: 3, peopleCount: .solo)
        var state = PoseFeature.State()
        state.generalPoses = [tappedPose]
        state.loadedGeneralFilter = PoseListFilter()
        let scrappedPages = LockIsolated<[Int]>([])
        let serverBookmarks = [makePose(id: 3, peopleCount: .solo, isScrapped: true), makePose(id: 8, peopleCount: .duo, isScrapped: true)]
        let store = makeStore(initialState: state) {
            $0.poseClient.fetchScrappedPoseList = { page, _, _ in
                scrappedPages.withValue { $0.append(page) }
                return PoseListPage(poses: serverBookmarks, hasNext: false, totalCount: 2)
            }
        }

        await store.send(.onTapBookmark(tappedPose))
        await store.finish()
        await store.skipReceivedActions(strict: false)
        await store.send(.onTapScrapMode)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(scrappedPages.value == [0])
        #expect(store.state.visiblePoses.map(\.id) == [3, 8])
        #expect(store.state.displayedPoseCount == 2)
    }

    @Test("북마크 목록을 받은 뒤에는 하트를 누르면 북마크 개수가 늘고, 다시 누르면 줄어든다")
    func onTapBookmark_afterScrappedListLoaded_updatesBookmarkCount() async {
        let pose = makePose(id: 5, peopleCount: .trio)
        var state = PoseFeature.State()
        state.generalPoses = [pose]
        state.loadedGeneralFilter = PoseListFilter()
        state.scrappedPoses = [makePose(id: 1, peopleCount: .solo, isScrapped: true)]
        state.scrappedTotalCount = 1
        state.isScrappedListLoaded = true
        let store = makeStore(initialState: state)

        await store.send(.onTapBookmark(pose))
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.scrappedPoses.map(\.id) == [5, 1])
        #expect(store.state.scrappedTotalCount == 2)

        await store.send(.onTapBookmark(store.state.generalPoses[id: 5]!))
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.scrappedPoses.map(\.id) == [1])
        #expect(store.state.scrappedTotalCount == 1)
    }

    @Test("북마크 목록의 받지 않은 뒷페이지에 있는 포즈를 해제해도 북마크 개수가 하나 준다")
    func onTapBookmark_unbookmarkingUnloadedPose_decrementsBookmarkCount() async {
        let pose = makePose(id: 30, peopleCount: .duo, isScrapped: true)
        let store = makeStore(initialState: makePartiallyLoadedBookmarkState(with: pose))

        await store.send(.onTapBookmark(pose))
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(store.state.scrappedPoses.count == 20)
        #expect(store.state.scrappedTotalCount == 50)
    }

    @Test("받지 않은 뒷페이지에 있는 포즈의 북마크 해제가 실패해 되돌리면 북마크 개수도 원래대로 돌아온다")
    func onTapBookmark_unbookmarkingUnloadedPoseFails_restoresBookmarkCount() async {
        let pose = makePose(id: 30, peopleCount: .duo, isScrapped: true)
        let store = makeStore(initialState: makePartiallyLoadedBookmarkState(with: pose)) {
            $0.poseClient.scrapPose = { _ in throw BookmarkFailure() }
        }

        await store.send(.onTapBookmark(pose))
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(store.state.generalPoses[id: 30]?.isScrapped == true)
        #expect(store.state.scrappedTotalCount == 51)
    }

    @Test("북마크 탭 밖에서 북마크를 바꾸면, 북마크 탭에 들어갈 때 첫 페이지부터 다시 받아 서버 목록과 개수로 맞춘다")
    func enteringBookmarkTab_afterBookmarkChangeOutside_refetchesFirstPage() async {
        let server = OffsetBookmarkServer(ids: Array(1...51))
        let newBookmark = makePose(id: 100, peopleCount: .solo)
        var state = makeBookmarkLoadedState(server.page(0, size: 20), nextPage: 1, isBookmarkTab: false)
        state.generalPoses = [newBookmark]
        state.loadedGeneralFilter = PoseListFilter()
        state.requestedGeneralFilter = PoseListFilter()
        let requests = LockIsolated<[ScrapListRequest]>([])
        let store = makeStore(initialState: state) {
            $0.poseClient.scrapPose = { server.toggle($0) }
            $0.poseClient.fetchScrappedPoseList = { page, size, refresh in
                requests.withValue { $0.append(ScrapListRequest(page: page, refresh: refresh)) }
                return server.page(page, size: size)
            }
        }

        await store.send(.onTapBookmark(newBookmark))
        await store.finish()
        await store.skipReceivedActions(strict: false)
        await store.send(.onTapScrapMode)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value == [ScrapListRequest(page: 0, refresh: true)])
        #expect(store.state.visiblePoses.map(\.id) == server.page(0, size: 20).poses.map(\.id))
        #expect(store.state.displayedPoseCount == 52)

        // 그 뒤로 바꾼 것이 없으면 탭을 오가도 다시 받지 않습니다.
        await store.send(.onTapScrapMode)
        await store.send(.onTapScrapMode)
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(requests.value.count == 1)
    }

    @Test("북마크 목록을 받는 사이에 북마크를 바꾸면, 바꾸기 전 내용일 수 있는 응답은 버리고 다시 받는다")
    func scrappedListResponse_afterBookmarkChangeDuringRequest_isDiscardedAndRefetched() async {
        let server = OffsetBookmarkServer(ids: Array(1...51))
        let requests = LockIsolated<[ScrapListRequest]>([])
        let (gate, openGate) = AsyncStream<Void>.makeStream()
        let (requested, markRequested) = AsyncStream<Void>.makeStream()
        let store = makeStore(initialState: makeBookmarkLoadedState(server.page(0, size: 20), nextPage: 1)) {
            $0.poseClient.scrapPose = { server.toggle($0) }
            $0.poseClient.fetchScrappedPoseList = { page, size, refresh in
                let requestCount = requests.withValue {
                    $0.append(ScrapListRequest(page: page, refresh: refresh))
                    return $0.count
                }
                // 응답은 요청을 받은 때의 서버 목록입니다. 첫 요청은 북마크를 바꿀 때까지 붙잡아 둡니다.
                let response = server.page(page, size: size)
                if requestCount == 1 {
                    markRequested.yield()
                    for await _ in gate { break }
                }
                return response
            }
        }

        // 당겨서 새로고침하는 사이에 5번째 북마크를 해제합니다.
        await store.send(.onRefresh)
        for await _ in requested { break }
        await store.send(.onTapBookmark(makePose(id: 5, peopleCount: .solo, isScrapped: true)))
        openGate.yield()
        openGate.finish()
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value == [ScrapListRequest(page: 0, refresh: true), ScrapListRequest(page: 0, refresh: true)])
        #expect(store.state.visiblePoses.map(\.id) == server.page(0, size: 20).poses.map(\.id))
        #expect(store.state.displayedPoseCount == 50)
    }

    @Test("북마크 탭에서 해제한 뒤 다음 페이지를 받으면 앞 페이지부터 다시 받아, 빠지거나 겹치는 포즈가 없다")
    func loadMore_afterUnbookmarkingLoadedPoses_refetchesFromPreviousPage() async {
        let server = OffsetBookmarkServer(ids: Array(1...51))
        let requests = LockIsolated<[ScrapListRequest]>([])
        let store = makeStore(initialState: makeBookmarkLoadedState(server.page(0, size: 20), nextPage: 1)) {
            $0.poseClient.scrapPose = { server.toggle($0) }
            $0.poseClient.fetchScrappedPoseList = { page, size, refresh in
                requests.withValue { $0.append(ScrapListRequest(page: page, refresh: refresh)) }
                return server.page(page, size: size)
            }
        }

        // 51개 중 1~20번째를 받고 5·9·12번째를 해제하면, 서버에서는 21~23번째가 앞 페이지 자리로 당겨집니다.
        for id in [5, 9, 12] {
            await store.send(.onTapBookmark(makePose(id: id, peopleCount: .solo, isScrapped: true)))
        }
        await store.finish()
        await store.skipReceivedActions(strict: false)
        await store.send(.loadMoreItems)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value == [ScrapListRequest(page: 0, refresh: true), ScrapListRequest(page: 1, refresh: false)])
        #expect(store.state.scrappedPoses.map(\.id) == Array(server.ids.value.prefix(40)))

        // 그 뒤로 해제한 것이 없으면 다음 페이지만 받습니다.
        await store.send(.loadMoreItems)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value.count == 3)
        #expect(requests.value.last == ScrapListRequest(page: 2, refresh: false))
        #expect(store.state.scrappedPoses.map(\.id) == server.ids.value)
        #expect(store.state.displayedPoseCount == 48)
        #expect(store.state.isLastScrappedPage)
    }

    @Test("한 페이지보다 많이 해제했으면 그만큼 더 앞 페이지부터 다시 받는다")
    func loadMore_afterUnbookmarkingMoreThanPage_refetchesFromEarlierPage() async {
        let server = OffsetBookmarkServer(ids: Array(1...51))
        let loaded = PoseListPage(poses: server.page(0, size: 20).poses + server.page(1, size: 20).poses, hasNext: true, totalCount: 51)
        let requests = LockIsolated<[ScrapListRequest]>([])
        let store = makeStore(initialState: makeBookmarkLoadedState(loaded, nextPage: 2)) {
            $0.poseClient.scrapPose = { server.toggle($0) }
            $0.poseClient.fetchScrappedPoseList = { page, size, refresh in
                requests.withValue { $0.append(ScrapListRequest(page: page, refresh: refresh)) }
                return server.page(page, size: size)
            }
        }

        for id in 1...21 {
            await store.send(.onTapBookmark(makePose(id: id, peopleCount: .solo, isScrapped: true)))
        }
        await store.finish()
        await store.skipReceivedActions(strict: false)
        await store.send(.loadMoreItems)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        #expect(requests.value == [
            ScrapListRequest(page: 0, refresh: true),
            ScrapListRequest(page: 1, refresh: false),
            ScrapListRequest(page: 2, refresh: false)
        ])
        #expect(store.state.scrappedPoses.map(\.id) == server.ids.value)
        #expect(store.state.displayedPoseCount == 30)
        #expect(store.state.isLastScrappedPage)
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
            $0.poseClient.fetchPoseList = { _, _, _, _ in PoseListPage(poses: [], hasNext: false, totalCount: .zero) }
            $0.poseClient.fetchScrappedPoseList = { _, _, _ in PoseListPage(poses: [], hasNext: false, totalCount: .zero) }
            updateDependencies(&$0)
        }
        store.exhaustivity = .off
        return store
    }

    func makePose(id: PoseID, peopleCount: PeopleCountOption, relation: PoseRelation? = nil, isScrapped: Bool = false) -> Pose {
        Pose(
            id: id,
            peopleCountOption: peopleCount,
            imageURL: nil,
            isScrapped: isScrapped,
            contentType: .jpeg,
            width: nil,
            height: nil,
            relation: relation
        )
    }

    /// 북마크 51개 중 앞 20개(1~20)만 받은 상태입니다. 일반 목록의 `pose`는 받지 않은 뒷페이지에 있는 북마크입니다.
    func makePartiallyLoadedBookmarkState(with pose: Pose) -> PoseFeature.State {
        var state = PoseFeature.State()
        state.generalPoses = [pose]
        state.loadedGeneralFilter = PoseListFilter()
        state.scrappedPoses = IdentifiedArray(uniqueElements: (1...20).map { makePose(id: $0, peopleCount: .solo, isScrapped: true) })
        state.scrappedTotalCount = 51
        state.isScrappedListLoaded = true
        return state
    }

    /// 서버에서 북마크 목록을 `nextPage` 앞 페이지까지 받은 상태입니다. `isBookmarkTab`이면 북마크 탭을 보고 있습니다.
    func makeBookmarkLoadedState(_ loaded: PoseListPage, nextPage: Int, isBookmarkTab: Bool = true) -> PoseFeature.State {
        var state = PoseFeature.State()
        state.isSelectedScrap = isBookmarkTab
        state.scrappedPoses = IdentifiedArray(uniqueElements: loaded.poses)
        state.scrappedTotalCount = loaded.totalCount
        state.isScrappedListLoaded = true
        state.scrappedPage = nextPage
        state.isLastScrappedPage = loaded.hasNext == false
        if isBookmarkTab { state.visiblePoses = loaded.poses }
        return state
    }
}

/// 일반 목록 요청 하나입니다. 어떤 조건의 몇 번째 페이지를 새로고침으로 불렀는지 남깁니다.
private struct ListRequest: Equatable {
    let page: Int
    let filter: PoseListFilter
    let refresh: Bool
}

/// 북마크 목록 요청 하나입니다. 몇 번째 페이지를 새로고침으로 불렀는지 남깁니다.
private struct ScrapListRequest: Equatable {
    let page: Int
    let refresh: Bool
}

private struct BookmarkFailure: Error {}
