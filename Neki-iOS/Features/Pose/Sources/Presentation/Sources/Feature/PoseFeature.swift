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
        var isLoading: Bool = false
        
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
        case onRefresh
        case qrScanButtonTapped
        
        // Internal Actions (Async Results & Data Updates)
        case fetchListResponse(isScrapResult: Bool, Result<(poses: [Pose], hasNext: Bool), Error>)
        case updatePoseInList(Pose)
        
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
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - View Actions
            case .onAppear:
                if state.isSelectedScrap {
                    if state.scrappedPoses.isEmpty { return fetchPoses(state: &state, refreshNeeded: true) }
                } else {
                    if state.generalPoses.isEmpty { return fetchPoses(state: &state, refreshNeeded: true) }
                }
                return .none
                
            case .loadMoreItems:
                guard state.isLoading == false, state.isCurrentLastPage == false else { return .none }
                return fetchPoses(state: &state, refreshNeeded: false)
                
            case .onRefresh:
                return fetchPoses(state: &state, refreshNeeded: true)
                
            case .onTapFilter:
                state.sheetItem = .peopleCountFilter
                return .none
                
            case let .selectPeopleCount(option):
                state.selectedCountFilterOption = state.selectedCountFilterOption == option ? nil : option
                state.isSelectedScrap = false
                return .none
                
            case .onTapScrapMode:
                state.isSelectedScrap.toggle()
                state.selectedCountFilterOption = nil
                if state.isSelectedScrap, state.scrappedPoses.isEmpty {
                    return fetchPoses(state: &state, refreshNeeded: true)
                } else if state.isLoading == false, state.generalPoses.isEmpty {
                    return fetchPoses(state: &state, refreshNeeded: true)
                }
                return .none
                
            case let .selectPeopleCountForRandomPose(option):
                state.selectedRandomPoseCountSelectionOption = option
                return .none
                
            case .onTapRandomPoseRecommend:
                state.sheetItem = .randomPoseCountSelection
                return .none
                
            case .onTapStartRandomPoseCarousel:
                state.sheetItem = nil
                return .send(.delegate(.didTapStartRandomPose(state.selectedRandomPoseCountSelectionOption)))
                
            case let .imageTapped(pose):
                return .send(.delegate(.didTapImage(pose)))
                
            case .qrScanButtonTapped:
                return .send(.delegate(.qrScanButtonTapped))
                
                // MARK: - Internal Actions
            case let .updatePoseInList(pose):
                if state.generalPoses.contains(where: { $0.id == pose.id }) { state.generalPoses[id: pose.id] = pose }
                if pose.isScrapped {
                    if state.scrappedPoses.contains(where: { $0.id == pose.id }) == false {
                        guard state.scrappedPoses.isEmpty == false else { return .none }
                        state.scrappedPoses.append(pose)
                    } else {
                        state.scrappedPoses[id: pose.id] = pose
                    }
                } else {
                    state.scrappedPoses.remove(id: pose.id)
                }
                return .none
                
            case let .fetchListResponse(isScrapResult, .success((poses, hasNext))):
                state.isLoading = false
                if isScrapResult {
                    state.isLastScrappedPage = hasNext == false
                    if state.scrappedPage == .zero {
                        state.scrappedPoses = IdentifiedArray(uniqueElements: poses)
                    } else {
                        state.scrappedPoses.append(contentsOf: poses)
                    }
                    
                    guard hasNext else { return .none }
                    state.scrappedPage += 1
                } else {
                    state.isLastGeneralPage = hasNext == false
                    if state.generalPage == .zero {
                        state.generalPoses = IdentifiedArray(uniqueElements: poses)
                    } else {
                        state.generalPoses.append(contentsOf: poses)
                    }
                    
                    guard hasNext else { return .none }
                    state.generalPage += 1
                }
                return .none
                
            case let .fetchListResponse(_, .failure(error)):
                state.isLoading = false
                Logger.presentation.error("Pose List Fetching Failed: \(error)")
                return .none
                
                // MARK: - Default
            default:
                return .none
            }
        }
    }
    
    private func fetchPoses(state: inout State, refreshNeeded: Bool) -> Effect<Action> {
        state.isLoading = true
        let isScrapMode = state.isSelectedScrap
        
        if refreshNeeded {
            if isScrapMode {
                state.scrappedPage = .zero
                state.isLastScrappedPage = false
            } else {
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
}
