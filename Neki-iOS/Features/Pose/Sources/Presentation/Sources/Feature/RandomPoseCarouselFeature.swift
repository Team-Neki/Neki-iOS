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
        
        // Delegate Actions
        case poseUpdated(Pose)
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [count = state.activePeopleCount] send in
                    await send(.poseResponse(Result { try await poseClient.initializeRandomPose(peopleCount: count) }))
                }
                
            case .onDisappear:
                return .run { _ in
                    await poseClient.stopRandomPoseSuggestion()
                }
                
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
                
            case .onTapScrap:
                guard var pose = state.currentPose else { return .none }
                pose.isScrapped.toggle()
                state.currentPose = pose
                return .run { [id = pose.id] send in
                    await send(.scrapResponse(id, Result { try await poseClient.scrapPose(poseID: id) }))
                }
                
            case let .poseResponse(.success(pose)):
                state.isLoading = false
                state.currentPose = pose
                return .none
                
            case let .poseResponse(.failure(error)):
                state.isLoading = false
                // TODO: 플로터 띄...
                Logger.presentation.error("Random Pose Fetching Failed: \(error)")
                // TODO: 만약 NoHistory 에러면 그냥 이전 포즈사진이 없다는 거니까 무시하거나 플로터 띄워서 알려주면 될듯
                return .none
                
            case let .scrapResponse(id, .failure(error)):
                if error is CancellationError { return .none }
                if var pose = state.currentPose, pose.id == id {
                    pose.isScrapped.toggle(); state.currentPose = pose
                }
                Logger.presentation.error("Error occured while scrapping pose: ID-\(id) / Error: \(error)")
                return .none
                
            default:
                return .none
            }
        }
    }
}
