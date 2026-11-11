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
    }
    
    @ObservableState
    struct State: Equatable {
        // Data
        var generalPoses: IdentifiedArrayOf<Pose> = []
        var scrappedPoses: IdentifiedArrayOf<Pose> = []
        var visiblePoses: [Pose] = []
        var lastVisiblePoseID: PoseID?
        
        // Pagination & Filter
        var generalPage: Int = .zero
        var isLastGeneralPage: Bool = false
        var scrappedPage: Int = .zero
        var isLastScrappedPage: Bool = false
        
        @ObservationIgnored let pageSize: Int = 20
        var isGeneralLoading: Bool = false
        var isScrappedLoading: Bool = false
        
        var currentPage: Int { isSelectedScrap ? scrappedPage : generalPage }
        var isCurrentLastPage: Bool { isSelectedScrap ? isLastScrappedPage : isLastGeneralPage }
        
        /// "N개의 포즈"에 보여 줄 개수입니다. 불러온 목록에 필터를 적용한 개수이고, 전체 개수는 #424에서 연결합니다.
        ///
        /// 아직 받은 포즈가 없으면 불러오는 중이거나 실패한 것이라 nil을 돌려줘 "0개"가 깜빡이지 않게 합니다. 끝까지 불러왔는데 비어 있으면 0입니다.
        var displayedPoseCount: Int? {
            let loadedPoses = isSelectedScrap ? scrappedPoses : generalPoses
            guard loadedPoses.isEmpty == false || isCurrentLastPage else { return nil }
            return visiblePoses.count
        }
        
        // Filter Options
        var selectedCountFilterOption: PeopleCountOption?
        /// 고른 관계 태그입니다. 고르면 인원수가 2인으로 바뀌고, 인원수가 2인이 아니게 되면 비워집니다.
        var selectedRelationFilterOption: PoseRelation?
        var isSelectedScrap: Bool = false
        
        /// 보이는 목록을 정하는 조건입니다.
        ///
        /// 관계 태그는 아직 목록을 거르지 않아 넣지 않았습니다(#424). 관계로 거르게 되면 여기와 `refreshVisiblePoses`에 함께 넣습니다.
        struct ListCondition: Equatable {
            let isScrap: Bool
            let peopleCount: PeopleCountOption?
        }
        
        var listCondition: ListCondition { ListCondition(isScrap: isSelectedScrap, peopleCount: selectedCountFilterOption) }
        
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
        case fetchListResponse(isScrapResult: Bool, Result<(poses: [Pose], hasNext: Bool), Error>)
        case updatePoseInList(Pose)
        case bookmarkResponse(Pose, Result<Void, Error>)
        
        // Delegate Action
        case delegate(Delegate)
        enum Delegate {
            case didTapImage(Pose)
            case didTapStartRandomPose(PeopleCountOption)
            case qrScanButtonTapped
            case requestNotificationList
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
                let fetchEffect: Effect<Action>
                if state.isSelectedScrap {
                    guard state.isScrappedLoading == false, state.scrappedPoses.isEmpty else { return trackingEffect }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                } else {
                    guard state.isGeneralLoading == false, state.generalPoses.isEmpty else { return trackingEffect }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                }
                return .merge(trackingEffect, fetchEffect)
                
            case .fullScreenCoverDismissed:
                return .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseView) }
                
            case .loadMoreItems:
                if state.isSelectedScrap {
                    guard state.isScrappedLoading == false, state.isLastScrappedPage == false else { return .none }
                } else {
                    guard state.isGeneralLoading == false, state.isLastGeneralPage == false else { return .none }
                }
                return fetchPoses(state: &state, refreshNeeded: false)
                
            case .onRefresh:
                return fetchPoses(state: &state, refreshNeeded: true)
                
            case .onTapFilter:
                state.sheetItem = .peopleCountFilter
                return .none
                
            case let .selectPeopleCount(option):
                let previousCondition = state.listCondition
                state.togglePeopleCountFilter(option)
                applyListConditionChange(&state, from: previousCondition)
                guard let peopleCount = extractPeopleCount(from: state.selectedCountFilterOption) else { return .none }
                let event = PoseAnalyticsEvent.poseFilterToggle(peopleCount: peopleCount)
                return .run { _ in await analytics.logEvent(event) }
                
            case let .onTapRelationFilter(relation):
                // 관계 태그는 이벤트 명세에 없어 기록하지 않습니다. 북마크에서 일반 목록으로 돌아와도 인원수 선택처럼 다시 불러오지 않습니다.
                let previousCondition = state.listCondition
                state.toggleRelationFilter(relation)
                applyListConditionChange(&state, from: previousCondition)
                return .none
                
            case .onTapScrapMode:
                let previousCondition = state.listCondition
                state.toggleBookmarkFilter()
                applyListConditionChange(&state, from: previousCondition)
                
                let trackingEffect: Effect<Action> = .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseBookmarkFilter) }
                let fetchEffect: Effect<Action>
                
                if state.isSelectedScrap {
                    guard state.isScrappedLoading == false, state.scrappedPoses.isEmpty else { return trackingEffect }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                } else {
                    guard state.isGeneralLoading == false, state.generalPoses.isEmpty else { return trackingEffect }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                }
                return .merge(trackingEffect, fetchEffect)
                
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
                if state.generalPoses.contains(where: { $0.id == pose.id }) { state.generalPoses[id: pose.id] = pose }
                if pose.isScrapped {
                    if state.scrappedPoses.contains(where: { $0.id == pose.id }) {
                        state.scrappedPoses[id: pose.id] = pose
                    } else {
                        state.scrappedPoses.insert(pose, at: .zero)
                    }
                } else {
                    state.scrappedPoses.remove(id: pose.id)
                }
                refreshVisiblePoses(&state)
                return .none
                
            case let .fetchListResponse(isScrapResult, .success((poses, hasNext))):
                if isScrapResult {
                    state.isScrappedLoading = false
                    state.isLastScrappedPage = hasNext == false
                    if state.scrappedPage == .zero { state.scrappedPoses = IdentifiedArray(uniqueElements: poses) }
                    else { state.scrappedPoses.append(contentsOf: poses) }
                    if hasNext { state.scrappedPage += 1 }
                } else {
                    state.isGeneralLoading = false
                    state.isLastGeneralPage = hasNext == false
                    if state.generalPage == .zero { state.generalPoses = IdentifiedArray(uniqueElements: poses) }
                    else { state.generalPoses.append(contentsOf: poses) }
                    if hasNext { state.generalPage += 1 }
                }
                refreshVisiblePoses(&state)
                return .none
                
            case let .fetchListResponse(isScrapResult, .failure(error)):
                if isScrapResult { state.isScrappedLoading = false }
                else { state.isGeneralLoading = false }
                
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
    func fetchPoses(state: inout State, refreshNeeded: Bool) -> Effect<Action> {
        let isScrapMode = state.isSelectedScrap
        
        if isScrapMode {
            state.isScrappedLoading = true
            if refreshNeeded {
                state.scrappedPage = .zero
                state.isLastScrappedPage = false
            }
        } else {
            state.isGeneralLoading = true
            if refreshNeeded {
                state.generalPage = .zero
                state.isLastGeneralPage = false
            }
        }
        
        let page = isScrapMode ? state.scrappedPage : state.generalPage
        let pageSize = state.pageSize
        return .run { send in
            await send(.fetchListResponse(isScrapResult: isScrapMode, Result {
                if isScrapMode {
                    return try await poseClient.fetchScrappedPoseList(page: page, pageSize: pageSize, refresh: refreshNeeded)
                } else {
                    return try await poseClient.fetchPoseList(page: page, pageSize: pageSize, refresh: refreshNeeded)
                }
            }))
        }
    }
    
    func extractPeopleCount(from option: PeopleCountOption?) -> Int? { option?.rawValue }

    func refreshVisiblePoses(_ state: inout State) {
        let targetPoses = state.isSelectedScrap ? state.scrappedPoses : state.generalPoses
        guard let countOption = state.selectedCountFilterOption else {
            state.visiblePoses = Array(targetPoses)
            state.lastVisiblePoseID = state.visiblePoses.last?.id
            return
        }

        var visiblePoses: [Pose] = []
        visiblePoses.reserveCapacity(targetPoses.count)
        targetPoses.forEach {
            guard $0.peopleCountOption == countOption else { return }
            visiblePoses.append($0)
        }
        state.visiblePoses = visiblePoses
        state.lastVisiblePoseID = visiblePoses.last?.id
    }
    
    /// 목록 조건이 바뀐 경우에만 보이는 목록을 다시 거르고, 화면이 맨 위로 이동하도록 세대를 올립니다.
    func applyListConditionChange(_ state: inout State, from previousCondition: State.ListCondition) {
        guard state.listCondition != previousCondition else { return }
        refreshVisiblePoses(&state)
        state.scrollToTopGeneration &+= 1
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
