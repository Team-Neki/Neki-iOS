//
//  PoseFeedFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import os

@Reducer
struct PoseFeature {
    private enum CancelID: Hashable {
        case scrap(PoseID)
        case generalList
        case scrappedList
    }
    
    /// 목록 응답이 어느 목록의 것인지 나타냅니다. 일반 목록은 요청한 조건을 함께 담아, 조건을 바꾼 뒤 늦게 온 응답을 가려냅니다.
    enum ListScope: Equatable, Sendable {
        case general(PoseListFilter)
        case scrap
    }
    
    @ObservableState
    struct State: Equatable {
        // Data
        var generalPoses: IdentifiedArrayOf<Pose> = []
        var scrappedPoses: IdentifiedArrayOf<Pose> = []
        var visiblePoses: [Pose] = []
        /// 이 포즈 카드 중 하나가 화면 근처에 나타나면 다음 페이지를 부릅니다. 보이는 목록의 끝 몇 개라, 끝에 닿기 전에 미리 받습니다.
        var paginationTriggerPoseIDs: Set<PoseID> = []
        
        // Pagination & Filter
        var generalPage: Int = .zero
        var isLastGeneralPage: Bool = false
        var scrappedPage: Int = .zero
        var isLastScrappedPage: Bool = false
        
        @ObservationIgnored let pageSize: Int = 20
        /// 다음 페이지 신호를 보내는 끝 카드 수입니다. 두 열이라 끝에서 약 세 줄 전입니다.
        static let paginationPrefetchCount = 6
        var isGeneralLoading: Bool = false
        var isScrappedLoading: Bool = false
        /// `generalPoses`를 받은 조건입니다. 아직 받은 목록이 없으면 nil입니다.
        var loadedGeneralFilter: PoseListFilter?
        /// 마지막으로 요청한 일반 목록 조건입니다. 이 조건이 아닌 응답은 버립니다.
        var requestedGeneralFilter: PoseListFilter?
        /// 서버가 알려 준 조건별 전체 개수입니다. 첫 페이지를 받을 때마다 바뀝니다.
        var generalTotalCount: Int?
        var scrappedTotalCount: Int?
        /// 북마크 목록을 서버에서 받았는지입니다. 받기 전에는 하트로 바꾼 포즈를 북마크 목록에 넣지 않고, 북마크 칩을 누를 때 서버에서 받습니다.
        var isScrappedListLoaded: Bool = false
        /// 북마크 탭 밖에서 북마크를 바꿔, 받아 둔 북마크 목록의 순서와 개수가 서버와 다를 수 있는지입니다. 북마크 탭에 들어갈 때 첫 페이지부터 다시 받습니다.
        var isScrappedListStale: Bool = false
        /// 받아 둔 북마크 목록에서 뺀 포즈 수입니다. 서버 목록도 그만큼 앞으로 당겨져 있어, 다음 페이지를 받을 때 그만큼 앞에서부터 다시 받습니다.
        var scrappedListShift: Int = .zero
        /// 북마크가 바뀔 때마다 1씩 오릅니다.
        var bookmarkGeneration: UInt = .zero
        /// 북마크 목록을 요청할 때의 `bookmarkGeneration`입니다. 응답이 올 때 값이 다르면 그 사이 북마크가 바뀐 것이라 응답을 버립니다.
        var requestedScrappedListGeneration: UInt?
        
        var currentPage: Int { isSelectedScrap ? scrappedPage : generalPage }
        var isCurrentLastPage: Bool { isSelectedScrap ? isLastScrappedPage : isLastGeneralPage }
        
        /// "N개의 포즈"에 보여 줄 개수입니다. 서버가 알려 준 지금 조건의 전체 개수입니다.
        ///
        /// 조건을 바꾼 뒤 새 첫 페이지가 오기 전이거나 응답에 개수가 없으면 nil을 돌려줘 개수만 숨깁니다.
        var displayedPoseCount: Int? {
            if isSelectedScrap { return scrappedTotalCount }
            guard loadedGeneralFilter == listFilter else { return nil }
            return generalTotalCount
        }
        
        // Filter Options
        var selectedCountFilterOption: PeopleCountOption?
        /// 고른 관계 태그입니다. 고르면 인원수가 2인으로 바뀌고, 인원수가 2인이 아니게 되면 비워집니다.
        var selectedRelationFilterOption: PoseRelation?
        var isSelectedScrap: Bool = false
        
        /// 보이는 목록을 정하는 조건입니다.
        struct ListCondition: Equatable {
            let isScrap: Bool
            let filter: PoseListFilter
        }
        
        /// 서버에 보낼 일반 목록 조건입니다. 북마크 목록은 조건 없이 받고, 북마크를 켜면 인원수와 관계가 비워집니다.
        var listFilter: PoseListFilter { PoseListFilter(peopleCount: selectedCountFilterOption, relation: selectedRelationFilterOption) }
        var listCondition: ListCondition { ListCondition(isScrap: isSelectedScrap, filter: listFilter) }
        
        // Scroll
        /// 목록 조건이 바뀔 때마다 1씩 오릅니다. 화면은 값이 바뀌었는지만 보고 목록 맨 위로 이동합니다.
        var scrollToTopGeneration: UInt = .zero
        
        // Sort
        /// 8-1은 최신순 고정이라(위키 10/31) 정렬 메뉴를 열지 않고 "최신순" 글자만 보여 줍니다. 인기순 정렬을 도입할 때 켭니다.
        static let isSortMenuEnabled = false
        var selectedSortOption: PoseSortOption = .latest
        var isSortMenuPresented: Bool = false
        
        // Sheet Presentation
        var sheetItem: PoseView.SheetType?
        var selectedRandomPoseCountSelectionOption: PeopleCountOption = .solo
    }
    
    enum Action: BindableAction {
        // User Actions
        case onAppear
        /// QR·알림 목록처럼 이 화면을 덮은 전체 화면이 닫혀 다시 보일 때 받습니다. 이때는 onAppear가 다시 불리지 않아 메인 탭이 알립니다.
        case fullScreenCoverDismissed
        case loadMoreItems
        case onTapFilter
        case onTapScrapMode
        case selectPeopleCount(PeopleCountOption)
        /// 관계 태그(친구·커플·썸) 칩을 눌렀을 때 받습니다.
        case onTapRelationFilter(PoseRelation)
        /// 정렬 라벨을 눌렀을 때 받습니다. 정렬 메뉴가 꺼져 있으면 아무것도 하지 않습니다.
        case onTapSortMenu
        /// 정렬 메뉴에서 기준을 골랐을 때 받습니다. 서버 정렬은 인기순을 도입할 때 연결합니다.
        case selectSortOption(PoseSortOption)
        /// 정렬 메뉴 바깥을 눌렀을 때 받습니다.
        case dismissSortMenu
        case selectPeopleCountForRandomPose(PeopleCountOption)
        case onTapRandomPoseRecommend
        case onTapStartRandomPoseCarousel
        case imageTapped(Pose)
        case onTapBookmark(Pose)
        case onRefresh
        case qrScanButtonTapped
        case notificationButtonTapped
        
        // Internal Actions (Async Results & Data Updates)
        case fetchListResponse(ListScope, page: Int, Result<PoseListPage, Error>)
        /// 하트로 북마크를 바꿨을 때(누름·실패 되돌림) 받습니다. 바꾼 만큼 북마크 목록과 개수에 반영합니다.
        case updatePoseInList(Pose)
        /// 상세 화면이 서버에서 받은 포즈 정보를 받습니다. 북마크를 바꾼 것이 아니어서 이미 받은 카드만 맞춥니다.
        case syncPoseInList(Pose)
        case bookmarkResponse(Pose, Result<Void, Error>)
        
        // Delegate Action
        case delegate(Delegate)
        enum Delegate {
            case didTapImage(Pose)
            case didTapStartRandomPose(PeopleCountOption)
            case qrScanButtonTapped
            case requestNotificationList
            /// 다음 페이지를 받아 보이는 목록에 붙였을 때 보냅니다. 열린 상세 화면이 늘어난 목록을 이어 넘깁니다.
            case didLoadMorePoses
        }
        
        // Binding Action
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.analyticsClient) private var analytics
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - View Actions
            case .onAppear:
                // 화면 진입은 목록을 이미 불러왔어도 화면이 보일 때마다 기록합니다.
                let trackingEffect: Effect<Action> = .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseView) }
                return .merge(trackingEffect, fetchFirstPageIfNeeded(&state))
                
            case .fullScreenCoverDismissed:
                return .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseView) }
                
            case .loadMoreItems:
                if state.isSelectedScrap {
                    guard state.isScrappedListLoaded, state.isScrappedLoading == false, state.isLastScrappedPage == false else { return .none }
                } else {
                    // 조건을 바꾼 뒤 새 첫 페이지가 오기 전에는 이전 조건의 다음 페이지를 부르지 않습니다.
                    guard state.loadedGeneralFilter == state.listFilter, state.isGeneralLoading == false, state.isLastGeneralPage == false else { return .none }
                }
                return fetchNextPage(&state)
                
            case .onRefresh:
                return fetchFirstPage(&state, refresh: true)
                
            case .onTapFilter:
                state.sheetItem = .peopleCountFilter
                return .none
                
            case let .selectPeopleCount(option):
                let previousCondition = state.listCondition
                state.togglePeopleCountFilter(option)
                let listEffect = applyListConditionChange(&state, from: previousCondition)
                guard let peopleCount = extractPeopleCount(from: state.selectedCountFilterOption) else { return listEffect }
                let event = PoseAnalyticsEvent.poseFilterToggle(peopleCount: peopleCount)
                return .merge(listEffect, .run { _ in await analytics.logEvent(event) })
                
            case let .onTapRelationFilter(relation):
                // 관계 태그는 이벤트 명세에 없어 기록하지 않습니다.
                let previousCondition = state.listCondition
                state.toggleRelationFilter(relation)
                return applyListConditionChange(&state, from: previousCondition)
                
            case .onTapScrapMode:
                let previousCondition = state.listCondition
                state.toggleBookmarkFilter()
                let listEffect = applyListConditionChange(&state, from: previousCondition)
                let trackingEffect: Effect<Action> = .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseBookmarkFilter) }
                return .merge(trackingEffect, listEffect)
                
            case .onTapSortMenu:
                guard State.isSortMenuEnabled else { return .none }
                state.isSortMenuPresented.toggle()
                return .none
                
            case let .selectSortOption(option):
                state.selectedSortOption = option
                state.isSortMenuPresented = false
                return .none
                
            case .dismissSortMenu:
                state.isSortMenuPresented = false
                return .none
                
            case let .selectPeopleCountForRandomPose(option):
                state.selectedRandomPoseCountSelectionOption = option
                return .none
                
            case .onTapRandomPoseRecommend:
                state.sheetItem = .randomPoseCountSelection
                return .none
                
            case .onTapStartRandomPoseCarousel:
                state.sheetItem = nil
                // 랜덤 포즈 시작은 랜덤 포즈 화면을 띄우는 포즈 코디네이터가 기록합니다.
                return .send(.delegate(.didTapStartRandomPose(state.selectedRandomPoseCountSelectionOption)))
                
            case let .imageTapped(pose):
                let event = PoseAnalyticsEvent.poseDetailClick(
                    poseID: pose.id,
                    peopleCount: pose.peopleCountOption.rawValue,
                    entryPoint: state.isSelectedScrap ? .bookmark : .list
                )
                return .merge(
                    .run { _ in await analytics.logEvent(event) },
                    .send(.delegate(.didTapImage(pose)))
                )
                
            case .qrScanButtonTapped:
                return .send(.delegate(.qrScanButtonTapped))

            case .notificationButtonTapped:
                return .send(.delegate(.requestNotificationList))
                
            case let .onTapBookmark(pose):
                var updatedPose = pose
                updatedPose.isScrapped.toggle()
                let scrapEffect: Effect<Action> = .run { [updatedPose] send in
                    await send(.bookmarkResponse(updatedPose, Result { try await poseClient.scrapPose(pose.id) }))
                }
                .cancellable(id: CancelID.scrap(pose.id), cancelInFlight: true)
                let trackingEffect: Effect<Action> = .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseBookmark) }
                
                return .merge(scrapEffect, trackingEffect, .send(.updatePoseInList(updatedPose)))
                
                // MARK: - Internal Actions
            case let .updatePoseInList(pose):
                state.applyBookmarkChange(pose)
                refreshVisiblePoses(&state)
                return .none
                
            case let .syncPoseInList(pose):
                state.syncFetchedPose(pose)
                refreshVisiblePoses(&state)
                return .none
                
            case let .fetchListResponse(scope, page, .success(result)):
                switch scope {
                case let .general(filter):
                    guard state.requestedGeneralFilter == filter else { return .none }
                    state.isGeneralLoading = false
                    state.isLastGeneralPage = result.hasNext == false
                    if page == .zero {
                        state.generalPoses = IdentifiedArray(uniqueElements: result.poses)
                        state.loadedGeneralFilter = filter
                        state.generalTotalCount = result.totalCount
                    } else {
                        state.generalPoses.append(contentsOf: result.poses)
                    }
                    if result.hasNext { state.generalPage = page + 1 }
                    
                case .scrap:
                    state.isScrappedLoading = false
                    // 요청한 뒤 북마크가 바뀌었으면 바뀌기 전 내용일 수 있어 버리고 다시 받습니다.
                    guard state.requestedScrappedListGeneration == state.bookmarkGeneration else {
                        return refetchDiscardedScrappedList(&state, page: page)
                    }
                    state.isLastScrappedPage = result.hasNext == false
                    if page == .zero {
                        state.scrappedPoses = IdentifiedArray(uniqueElements: result.poses)
                        state.scrappedTotalCount = result.totalCount
                        state.isScrappedListLoaded = true
                        state.isScrappedListStale = false
                    } else {
                        // 앞 페이지부터 다시 받았으면 이미 받은 포즈는 건너뛰고, 당겨진 포즈만 끝에 붙습니다.
                        state.scrappedPoses.append(contentsOf: result.poses)
                    }
                    // 요청할 때 당겨져 있던 만큼을 다시 받았습니다.
                    state.scrappedListShift = .zero
                    if result.hasNext { state.scrappedPage = page + 1 }
                }
                refreshVisiblePoses(&state)
                // 다음 페이지를 받았으면 열린 상세 화면이 이어 넘기도록 알립니다.
                return page == .zero ? .none : .send(.delegate(.didLoadMorePoses))
                
            case let .fetchListResponse(scope, page, .failure(error)):
                switch scope {
                case let .general(filter):
                    guard state.requestedGeneralFilter == filter else { return .none }
                    state.isGeneralLoading = false
                    // 첫 페이지를 못 받았으면 요청 기록을 지워, 화면에 다시 들어오거나 조건을 다시 고르면 다시 부르게 합니다.
                    if page == .zero, state.loadedGeneralFilter != filter { state.requestedGeneralFilter = nil }
                    
                case .scrap:
                    state.isScrappedLoading = false
                }
                
                Logger.presentation.error("Pose List Fetching Failed: \(error)")
                return .none
                
            case .bookmarkResponse(_, .success):
                return .none
                
            case let .bookmarkResponse(pose, .failure(error)):
                if error is CancellationError { return .none }
                Logger.presentation.error("Bookmark toggle failed: \(error)")
                var rolledBackPose = pose
                rolledBackPose.isScrapped.toggle()
                return .send(.updatePoseInList(rolledBackPose))
                
                // MARK: - Default
            default:
                return .none
            }
        }
    }
}


// MARK: - PoseFeature + Helpers

private extension PoseFeature {
    /// 지금 조건의 목록을 아직 받지 않았고 부르는 중도 아니면 첫 페이지를 부릅니다.
    ///
    /// 받아 둔 조건으로 돌아왔으면 새로 부르지 않고, 다른 조건으로 부르던 요청만 정리합니다.
    func fetchFirstPageIfNeeded(_ state: inout State) -> Effect<Action> {
        if state.isSelectedScrap {
            // 북마크 탭 밖에서 북마크를 바꿨으면 받아 둔 목록이 있어도 첫 페이지부터 다시 받습니다. 다음 페이지를 받던 요청은 취소됩니다.
            if state.isScrappedListStale { return fetchFirstPage(&state, refresh: true) }
            guard state.isScrappedListLoaded == false, state.isScrappedLoading == false else { return .none }
            return fetchFirstPage(&state, refresh: true)
        }
        
        let filter = state.listFilter
        if state.loadedGeneralFilter == filter {
            // 다른 조건의 응답이 늦게 와서 받아 둔 목록을 덮어쓰지 않도록, 그 요청을 취소하고 요청 기록을 이 조건으로 되돌립니다.
            // 취소한 요청은 응답을 보내지 않으므로 불러오는 중 표시도 여기서 끕니다. 그래야 이 조건의 다음 페이지를 부를 수 있습니다.
            guard state.requestedGeneralFilter != filter else { return .none }
            state.requestedGeneralFilter = filter
            state.isGeneralLoading = false
            return .cancel(id: CancelID.generalList)
        }
        guard state.isGeneralLoading == false || state.requestedGeneralFilter != filter else { return .none }
        // 처음 받을 때는 저장소에 남은 이전 페이지를 쓰지 않습니다.
        return fetchFirstPage(&state, refresh: state.loadedGeneralFilter == nil)
    }
    
    func fetchFirstPage(_ state: inout State, refresh: Bool) -> Effect<Action> {
        fetchPage(&state, page: .zero, refresh: refresh)
    }
    
    func fetchNextPage(_ state: inout State) -> Effect<Action> {
        guard state.isSelectedScrap, state.scrappedListShift > .zero else {
            return fetchPage(&state, page: state.currentPage, refresh: false)
        }
        // 받아 둔 북마크를 뺀 만큼 서버 목록이 앞으로 당겨져, 다음 페이지만 받으면 당겨진 포즈가 빠집니다. 그 포즈가 있는 앞 페이지부터 다시 받습니다.
        // 저장소에 남은 앞 페이지는 빼기 전 내용이라, 저장소 기억을 비우고 서버에서 받습니다.
        let nextPage = state.scrappedPage
        let pagesBack = (state.scrappedListShift + state.pageSize - 1) / state.pageSize
        return fetchScrappedPages(&state, pages: max(nextPage - pagesBack, .zero)...nextPage, refresh: true)
    }
    
    /// 지금 목록의 한 페이지를 부릅니다. 같은 목록에서 부르던 요청은 취소합니다.
    func fetchPage(_ state: inout State, page: Int, refresh: Bool) -> Effect<Action> {
        if state.isSelectedScrap { return fetchScrappedPages(&state, pages: page...page, refresh: refresh) }
        
        let pageSize = state.pageSize
        let filter = state.listFilter
        state.isGeneralLoading = true
        state.requestedGeneralFilter = filter
        return .run { send in
            await send(.fetchListResponse(.general(filter), page: page, Result {
                try await poseClient.fetchPoseList(page: page, pageSize: pageSize, filter: filter, refresh: refresh)
            }))
        }
        .cancellable(id: CancelID.generalList, cancelInFlight: true)
    }
    
    /// 북마크 목록의 페이지들을 차례로 받아 한 응답으로 합칩니다. 같은 목록에서 부르던 요청은 취소합니다.
    ///
    /// `refresh`면 첫 페이지를 받을 때 저장소에 남은 북마크 페이지를 지웁니다. 응답은 마지막 페이지 번호로 보냅니다.
    func fetchScrappedPages(_ state: inout State, pages: ClosedRange<Int>, refresh: Bool) -> Effect<Action> {
        let pageSize = state.pageSize
        state.isScrappedLoading = true
        state.requestedScrappedListGeneration = state.bookmarkGeneration
        return .run { send in
            await send(.fetchListResponse(.scrap, page: pages.upperBound, Result {
                var poses: [Pose] = []
                var lastPage = PoseListPage(poses: [], hasNext: false, totalCount: nil)
                for page in pages {
                    lastPage = try await poseClient.fetchScrappedPoseList(page: page, pageSize: pageSize, refresh: refresh && page == pages.lowerBound)
                    poses.append(contentsOf: lastPage.poses)
                }
                return PoseListPage(poses: poses, hasNext: lastPage.hasNext, totalCount: lastPage.totalCount)
            }))
        }
        .cancellable(id: CancelID.scrappedList, cancelInFlight: true)
    }
    
    /// 버린 북마크 목록 응답을 다시 받습니다.
    ///
    /// 북마크 탭을 보고 있지 않으면 지금 받지 않고, 북마크 탭에 들어올 때 첫 페이지부터 받게 합니다.
    func refetchDiscardedScrappedList(_ state: inout State, page: Int) -> Effect<Action> {
        guard state.isSelectedScrap else {
            if state.isScrappedListLoaded { state.isScrappedListStale = true }
            return .none
        }
        return page == .zero ? fetchFirstPage(&state, refresh: true) : fetchNextPage(&state)
    }
    
    func extractPeopleCount(from option: PeopleCountOption?) -> Int? { option?.rawValue }

    /// 보이는 목록을 지금 조건으로 거릅니다.
    ///
    /// 서버가 거른 목록이면 그대로입니다. 조건을 바꾼 직후에는 새 첫 페이지가 오기 전까지 이미 받은 목록에서 맞는 포즈만 먼저 보여 줍니다.
    func refreshVisiblePoses(_ state: inout State) {
        let filter = state.listFilter
        let targetPoses = state.isSelectedScrap ? state.scrappedPoses : state.generalPoses
        let visiblePoses = targetPoses.elements.filter { filter.matches($0) }
        state.visiblePoses = visiblePoses
        state.paginationTriggerPoseIDs = Set(visiblePoses.suffix(State.paginationPrefetchCount).map(\.id))
    }
    
    /// 목록 조건이 바뀐 경우에만 보이는 목록을 다시 거르고, 화면이 맨 위로 이동하도록 세대를 올린 뒤 새 조건의 첫 페이지를 부릅니다.
    func applyListConditionChange(_ state: inout State, from previousCondition: State.ListCondition) -> Effect<Action> {
        guard state.listCondition != previousCondition else { return .none }
        refreshVisiblePoses(&state)
        state.scrollToTopGeneration &+= 1
        return fetchFirstPageIfNeeded(&state)
    }
}


// MARK: - PoseFeature.State + Filter Rules

extension PoseFeature.State {
    /// 북마크 모드를 켜거나 끕니다. 고른 인원수와 관계 태그는 비웁니다.
    mutating func toggleBookmarkFilter() {
        isSelectedScrap.toggle()
        selectedCountFilterOption = nil
        selectedRelationFilterOption = nil
    }
    
    /// 인원수를 고릅니다. 이미 고른 인원수를 다시 누르면 해제합니다.
    ///
    /// 북마크 모드는 끕니다. 인원수가 2인이 아니게 되면 관계 태그도 비웁니다.
    mutating func togglePeopleCountFilter(_ option: PeopleCountOption) {
        let newOption: PeopleCountOption? = selectedCountFilterOption == option ? nil : option
        isSelectedScrap = false
        selectedCountFilterOption = newOption
        guard newOption != .duo else { return }
        selectedRelationFilterOption = nil
    }
    
    /// 관계 태그를 고릅니다. 이미 고른 태그를 다시 누르면 태그만 해제하고 2인은 남깁니다.
    ///
    /// 태그를 고르면 북마크 모드를 끄고 인원수를 2인으로 바꿉니다.
    mutating func toggleRelationFilter(_ relation: PoseRelation) {
        guard selectedRelationFilterOption != relation else {
            selectedRelationFilterOption = nil
            return
        }
        isSelectedScrap = false
        selectedCountFilterOption = .duo
        selectedRelationFilterOption = relation
    }
}


// MARK: - PoseFeature.State + Bookmark List

extension PoseFeature.State {
    /// 하트로 바꾼 북마크(누름·실패 되돌림)를 받은 목록과 북마크 개수에 반영합니다.
    ///
    /// 북마크가 실제로 바뀐 것이므로, 받은 북마크 목록에 없는 포즈를 해제해도 개수를 줄입니다.
    mutating func applyBookmarkChange(_ pose: Pose) {
        if generalPoses.contains(where: { $0.id == pose.id }) { generalPoses[id: pose.id] = pose }
        recordBookmarkChange()
        // 북마크 목록을 서버에서 받기 전에는 손대지 않습니다. 하트로 넣은 포즈만 남으면 북마크 칩을 눌러도 목록을 받지 않게 됩니다.
        guard isScrappedListLoaded else { return }
        if pose.isScrapped {
            if scrappedPoses.contains(where: { $0.id == pose.id }) {
                scrappedPoses[id: pose.id] = pose
            } else {
                scrappedPoses.insert(pose, at: .zero)
                scrappedTotalCount = scrappedTotalCount.map { $0 + 1 }
            }
        } else {
            // 받은 북마크 목록에 없는 포즈(아직 받지 않은 뒷페이지)를 해제해도 서버 개수는 하나 줄어듭니다. 목록에 있는지는 목록에서 뺄 때만 봅니다.
            if scrappedPoses.remove(id: pose.id) != nil { scrappedListShift += 1 }
            scrappedTotalCount = scrappedTotalCount.map { max($0 - 1, .zero) }
        }
    }
    
    /// 서버에서 받은 포즈 정보로 이미 받은 카드만 맞춥니다.
    ///
    /// 북마크를 바꾼 것이 아니므로 받은 목록에 없는 포즈는 넣지 않고 개수도 그대로 둡니다. 받지 않은 뒷페이지의 북마크인지, 북마크하지 않은 포즈인지 알 수 없기 때문입니다.
    /// 받은 북마크 목록에 있는데 북마크가 아니면 다른 곳에서 해제된 것이라, 목록에서 빼고 개수를 줄입니다.
    mutating func syncFetchedPose(_ pose: Pose) {
        if generalPoses.contains(where: { $0.id == pose.id }) { generalPoses[id: pose.id] = pose }
        guard scrappedPoses.contains(where: { $0.id == pose.id }) else { return }
        if pose.isScrapped {
            scrappedPoses[id: pose.id] = pose
        } else {
            recordBookmarkChange()
            scrappedPoses.remove(id: pose.id)
            scrappedListShift += 1
            scrappedTotalCount = scrappedTotalCount.map { max($0 - 1, .zero) }
        }
    }
    
    /// 북마크가 바뀐 것을 기록합니다.
    ///
    /// 받는 중인 북마크 목록 응답은 바뀌기 전 내용일 수 있어 버리게 합니다.
    /// 받아 둔 북마크 목록이 있는데 북마크 탭 밖에서 바뀌었으면, 순서와 개수를 서버 기준으로 맞추도록 북마크 탭에 들어갈 때 첫 페이지부터 다시 받게 합니다.
    private mutating func recordBookmarkChange() {
        bookmarkGeneration &+= 1
        if isScrappedListLoaded, isSelectedScrap == false { isScrappedListStale = true }
    }
}
