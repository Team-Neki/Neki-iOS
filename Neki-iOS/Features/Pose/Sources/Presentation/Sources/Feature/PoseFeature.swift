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
        var filteredPoses: IdentifiedArrayOf<Pose> {
            let targetPoses = isSelectedScrap ? scrappedPoses : generalPoses
            guard let countOption = selectedCountFilterOption else { return targetPoses }
            return targetPoses.filter { $0.peopleCountOption == countOption }
        }
        
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
        
        // Filter Options
        var selectedCountFilterOption: PeopleCountOption?
        var isSelectedScrap: Bool = false
        
        // Sheet Presentation
        var sheetItem: PoseView.SheetType?
        var selectedRandomPoseCountSelectionOption: PeopleCountOption = .solo
    }
    
    enum Action: BindableAction {
        // User Actions
        case onAppear
        case loadMoreItems
        case onTapFilter
        case onTapScrapMode
        case selectPeopleCount(PeopleCountOption)
        case selectPeopleCountForRandomPose(PeopleCountOption)
        case onTapRandomPoseRecommend
        case onTapStartRandomPoseCarousel
        case imageTapped(Pose)
        case onTapBookmark(Pose)
        case onRefresh
        case qrScanButtonTapped
        
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
                let fetchEffect: Effect<Action>
                if state.isSelectedScrap {
                    guard state.isScrappedLoading == false, state.scrappedPoses.isEmpty else { return .none }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                } else {
                    guard state.isGeneralLoading == false, state.generalPoses.isEmpty else { return .none }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                }
                return fetchEffect
                
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
                let isDeselecting = state.selectedCountFilterOption == option
                state.selectedCountFilterOption = isDeselecting ? nil : option
                state.isSelectedScrap = false
                guard let peopleCount = extractPeopleCount(from: state.selectedCountFilterOption) else { return .none }
                let event = PoseAnalyticsEvent.poseFilterToggle(peopleCount: peopleCount)
                return .run { _ in analytics.logEvent(event: event) }
                
            case .onTapScrapMode:
                state.isSelectedScrap.toggle()
                state.selectedCountFilterOption = nil
                
                let trackingEffect: Effect<Action> = .run { _ in analytics.logEvent(event: PoseAnalyticsEvent.poseBookmarkFilter) }
                let fetchEffect: Effect<Action>
                
                if state.isSelectedScrap {
                    guard state.isScrappedLoading == false, state.scrappedPoses.isEmpty else { return trackingEffect }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                } else {
                    guard state.isGeneralLoading == false, state.generalPoses.isEmpty else { return trackingEffect }
                    fetchEffect = fetchPoses(state: &state, refreshNeeded: true)
                }
                return .merge(trackingEffect, fetchEffect)
                
            case let .selectPeopleCountForRandomPose(option):
                state.selectedRandomPoseCountSelectionOption = option
                return .none
                
            case .onTapRandomPoseRecommend:
                state.sheetItem = .randomPoseCountSelection
                return .none
                
            case .onTapStartRandomPoseCarousel:
                state.sheetItem = nil
                return .merge(
                    .run { _ in analytics.logEvent(event: PoseAnalyticsEvent.randomPoseSuggestionStart) },
                    .send(.delegate(.didTapStartRandomPose(state.selectedRandomPoseCountSelectionOption)))
                )
                
            case let .imageTapped(pose):
                return .send(.delegate(.didTapImage(pose)))
                
            case .qrScanButtonTapped:
                return .send(.delegate(.qrScanButtonTapped))
                
            case let .onTapBookmark(pose):
                var updatedPose = pose
                updatedPose.isScrapped.toggle()
                let scrapEffect: Effect<Action> = .run { [updatedPose] send in
                    await send(.bookmarkResponse(updatedPose, Result { try await poseClient.scrapPose(pose.id) }))
                }
                .cancellable(id: CancelID.scrap(pose.id), cancelInFlight: true)
                
                return .merge(scrapEffect, .send(.updatePoseInList(updatedPose)))
                
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
                return .none
                
            case let .fetchListResponse(isScrapResult, .failure(error)):
                if isScrapResult { state.isScrappedLoading = false }
                else { state.isGeneralLoading = false }
                
                Logger.presentation.error("Pose List Fetching Failed: \(error)")
                return .none
                
            case .bookmarkResponse(_, .success):
                return .run { _ in analytics.logEvent(PoseAnalyticsEvent.poseBookmark) }
                
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
}
