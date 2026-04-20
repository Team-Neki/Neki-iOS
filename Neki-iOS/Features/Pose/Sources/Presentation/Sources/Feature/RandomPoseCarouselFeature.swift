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
    enum SlideDirection { case previous, next, none }
    
    private enum CancelID: Hashable {
        case poseRequest
        case scrap(PoseID)
    }
    
    @ObservableState
    struct State {
        @Shared(.appStorage("RandomPoseTutorial")) var isTutorialPresented: Bool = true
        
        var currentPose: Pose?
        var isLoading: Bool = false
        var activePeopleCount: PeopleCountOption
        var isScrapped: Bool { currentPose?.isScrapped ?? false }
        var isDismissing: Bool = false
        var slideDirection: SlideDirection = .none
        var totalSwipeCount: Int = .zero
        
        init(peopleCount: PeopleCountOption) { activePeopleCount = peopleCount }
    }
    
    enum Action {
        // Lifecycle Actions
        case onAppear
        
        // View Actions
        case closeTutorialOverlay
        case onTapClose
        case tapLeft, tapRight
        case onTapScrap
        case onTapDetail(Pose)
        
        // Internal Actions
        case poseResponse(Result<Pose, Error>)
        case scrapResponse(Pose, Result<Void, Error>)
        case flushResources
        
        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case poseUpdated(Pose)
            case routeToDetail(Pose)
        }
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - Lifecycle & View Actions
            case .onAppear:
                guard state.currentPose == nil else { return .none }
                state.isLoading = true
                return .run { [count = state.activePeopleCount] send in
                    await send(.poseResponse(Result { try await poseClient.initializeRandomPose(peopleCount: count) }))
                }
                
            case .closeTutorialOverlay:
                state.$isTutorialPresented.withLock { $0 = false }
                return .none
                
            case .onTapClose:
                let currentSwipeCount = state.totalSwipeCount
                return .run { send in
                    analytics.logEvent(event: PoseAnalyticsEvent.randomPoseSuggestionEnd(totalSwipeCount: currentSwipeCount))
                    await send(.flushResources)
                    await dismiss()
                }
                
            case .tapLeft:
                state.slideDirection = .previous
                state.isLoading = true
                state.totalSwipeCount += 1
                return .run { send in
                    await send(.poseResponse(Result { try await poseClient.startRandomPoseSuggestion(direction: .left) }))
                }
                .cancellable(id: CancelID.poseRequest, cancelInFlight: true)
                
            case .tapRight:
                state.slideDirection = .next
                state.isLoading = true
                state.totalSwipeCount += 1
                return .run { send in
                    await send(.poseResponse(Result { try await poseClient.startRandomPoseSuggestion(direction: .right) }))
                }
                .cancellable(id: CancelID.poseRequest, cancelInFlight: true)
                
                // MARK: - Scrap Logic (Optimistic)
            case .onTapScrap:
                guard var pose = state.currentPose else { return .none }
                let originalPose = pose
                pose.isScrapped.toggle()
                state.currentPose = pose
                
                let scrapEffect: Effect<Action> = .run { [originalPose, updatedPose = pose] send in
                    await send(.delegate(.poseUpdated(updatedPose)))
                    await send(.scrapResponse(originalPose, Result { try await poseClient.scrapPose(poseID: originalPose.id) }))
                }
                .cancellable(id: CancelID.scrap(pose.id), cancelInFlight: true)
                
                return scrapEffect
                
                // MARK: - Internal Actions
            case let .poseResponse(.success(pose)):
                state.isLoading = false
                state.currentPose = pose
                return .none
                
            case let .poseResponse(.failure(error)):
                state.isLoading = false
                Logger.presentation.error("Random Pose Fetching Failed: \(error)")
                return .none
                
            case .scrapResponse(_, .success):
                return .run { _ in analytics.logEvent(PoseAnalyticsEvent.poseBookmark) }
                
            case let .scrapResponse(originalPose, .failure(error)):
                if error is CancellationError { return .none }
                Logger.presentation.error("Error occured while scrapping pose: ID-\(originalPose.id) / Error: \(error)")
                
                if state.currentPose?.id == originalPose.id {
                    state.currentPose = originalPose
                    return .send(.delegate(.poseUpdated(originalPose)))
                }
                
                return .none
                
                // MARK: - Navigation
            case let .onTapDetail(pose):
                return .run { send in
                    await send(.delegate(.routeToDetail(pose)))
                }
                
            case .flushResources:
                return .run { _ in await poseClient.stopRandomPoseSuggestion() }
                
            case .delegate:
                return .none
            }
        }
    }
}
