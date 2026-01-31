//
//  RandomPoseCarouselFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation
import ComposableArchitecture
import os

@Reducer
struct RandomPoseCarouselFeature {
    @ObservableState
    struct State {
        @Shared(.appStorage("RandomPoseTutorial")) var isTutorialPresented: Bool = true
        
        var currentPose: Pose?
        var isLoading: Bool = false
        var activePeopleCount: PeopleCountOption
        var isScrapped: Bool { currentPose?.isScrapped ?? false }
        
        var isDismissing: Bool = false
        
        init(peopleCount: PeopleCountOption) { activePeopleCount = peopleCount }
    }
    
    enum Action {
        // Lifecycle Actions
        case onAppear
        case onDisappear
        
        // View Actions
        case closeTutorialOverlay
        case onTapClose
        case tapLeft, tapRight
        case onTapScrap
        case onTapDetail(Pose)
        
        // Internal Actions
        case poseResponse(Result<Pose, Error>)
        case scrapResponse(PoseID, Result<Void, Error>)
        case flushResources
        
        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case poseUpdated(Pose)
            case routeToDetail(Pose)
        }
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - Lifecycle & View Actions
            case .onAppear:
                state.isLoading = true
                return .run { [count = state.activePeopleCount] send in
                    await send(.poseResponse(Result { try await poseClient.initializeRandomPose(peopleCount: count) }))
                }
                
            case .onDisappear:
                if state.isDismissing { return .none }
                return .send(.flushResources)
                
            case .closeTutorialOverlay:
                state.$isTutorialPresented.withLock { $0 = false }
                return .none
                
            case .onTapClose:
                return .run { _ in await dismiss() }
                
            case .tapLeft:
                return .run { send in
                    await send(.poseResponse(Result { try await poseClient.startRandomPoseSuggestion(direction: .left) }))
                }
                
            case .tapRight:
                return .run { send in
                    await send(.poseResponse(Result { try await poseClient.startRandomPoseSuggestion(direction: .right) }))
                }
                
                // MARK: - Scrap Logic (Optimistic)
            case .onTapScrap:
                guard var pose = state.currentPose else { return .none }
                pose.isScrapped.toggle()
                state.currentPose = pose
                
                return .run { [id = pose.id, pose] send in
                    await send(.delegate(.poseUpdated(pose)))
                    await send(.scrapResponse(id, Result { try await poseClient.scrapPose(poseID: id) }))
                }
                
                // MARK: - Internal Actions
            case let .poseResponse(.success(pose)):
                state.isLoading = false
                state.currentPose = pose
                return .none
                
            case let .poseResponse(.failure(error)):
                state.isLoading = false
                Logger.presentation.error("Random Pose Fetching Failed: \(error)")
                return .none
                
            case let .scrapResponse(id, .failure(error)):
                if error is CancellationError { return .none }
                
                if var pose = state.currentPose, pose.id == id {
                    pose.isScrapped.toggle()
                    state.currentPose = pose
                    return .send(.delegate(.poseUpdated(pose)))
                }
                Logger.presentation.error("Error occured while scrapping pose: ID-\(id) / Error: \(error)")
                return .none
                
            case .scrapResponse:
                return .none
                
                // MARK: - Navigation
            case let .onTapDetail(pose):
                state.isDismissing = true
                return .run { send in
                    await send(.flushResources)
                    await send(.delegate(.routeToDetail(pose)))
                    await dismiss()
                }
                
            case .flushResources:
                return .run { _ in await poseClient.stopRandomPoseSuggestion() }
                
            case .delegate:
                return .none
            }
        }
    }
}
