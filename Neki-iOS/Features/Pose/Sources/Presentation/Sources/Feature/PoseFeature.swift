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
        @ObservationStateIgnored var poses: IdentifiedArrayOf<Pose> = []
        var filteredPoses: IdentifiedArrayOf<Pose> {
            guard isSelectedScrap == false else { return poses.filter(\.isScrapped) }
            guard let countOption = selectedCountFilterOption else { return poses }
            return poses.filter { $0.peopleCountOption == countOption }
        }
        
        // Pagination & Filter
        var page: Int = .zero
        @ObservationIgnored let pageSize: Int = 20
        var isLoading: Bool = false
        var isLastPage: Bool = false
        
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
        
        // Data Actions
        case fetchListResponse(Result<[Pose], Error>)
        case toggleScrapResponse(PoseID, Result<Void, Error>)
        
        // Delegate Action
        case updatePose(Pose)
        case moveToRandomPoseSuggestionMode(PeopleCountOption)
        
        // Binding Action
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.poseClient) private var poseClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear:
                guard state.poses.isEmpty else { return .none }
                return fetchPoses(state: &state, refreshNeeded: true)
                
            case .loadMoreItems:
                guard state.isLoading == false, state.isLastPage == false else { return .none }
                return fetchPoses(state: &state, refreshNeeded: false)
                
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
                return fetchPoses(state: &state, refreshNeeded: false)
                
            case let .selectPeopleCountForRandomPose(option):
                state.selectedRandomPoseCountSelectionOption = option
                return .none
                
            case .onTapRandomPoseRecommend:
                state.sheetItem = .randomPoseCountSelection
                return .none
                
            case .onTapStartRandomPoseCarousel:
                state.sheetItem = nil
                return .send(.moveToRandomPoseSuggestionMode(state.selectedRandomPoseCountSelectionOption))
                
            case let .fetchListResponse(.success(poses)):
                state.isLoading = false
                if poses.isEmpty {
                    state.isLastPage = true
                } else {
                    state.poses.append(contentsOf: poses)
                    state.page += 1
                }
                return .none
                
            case let .fetchListResponse(.failure(error)):
                state.isLoading = false
                // TODO: 에러 토스트 띄우는 것 고려
                Logger.presentation.error("Pose List Fetching Failed: \(error)")
                return .none
                
            default:
                return .none
            }
        }
    }
    
    private func fetchPoses(state: inout State, refreshNeeded: Bool) -> Effect<Action> {
        if refreshNeeded {
            state.poses.removeAll()
            state.page = .zero
            state.isLastPage = false
        }
        
        state.isLoading = true
        let currentPage = state.page
        let pageSize = state.pageSize
        let isScrapMode = state.isSelectedScrap
        return .run { send in
            await send(.fetchListResponse(Result {
                if isScrapMode {
                    return try await poseClient.fetchScrappedPoseList(page: currentPage, pageSize: pageSize)
                } else {
                    return try await poseClient.fetchPoseList(page: currentPage, pageSize: pageSize)
                }
            }))
        }
    }
}
