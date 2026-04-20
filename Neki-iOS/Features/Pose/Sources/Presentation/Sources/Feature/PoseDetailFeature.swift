//
//  PoseDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture
import os

@Reducer
struct PoseDetailFeature {
    @ObservableState
    struct State: Equatable {
        var poses: IdentifiedArrayOf<Pose>
        var selectedID: PoseID
        var currentPose: Pose? { poses[id: selectedID] }
        var isScrapped: Bool { currentPose?.isScrapped ?? false }
    }
    
    enum Action {
        // User Actions
        case onTapScrap
        case pageChanged(PoseID)
        case didTapBackButton
        
        // Internal Actions
        case scrapResponse(Pose, Result<Void, Error>)
        
        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case poseUpdated(Pose)
        }
    }
    
    private enum CancelID: Hashable {
        case scrap(PoseID)
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - View Actions
            case .onTapScrap:
                guard var pose = state.currentPose else { return .none }
                let originalPose = pose
                pose.isScrapped.toggle()
                state.poses[id: pose.id] = pose
                
                let scrapEffect: Effect<Action> = .run { [originalPose, updatedPose = pose] send in
                    await send(.delegate(.poseUpdated(updatedPose)))
                    await send(.scrapResponse(originalPose, Result { try await poseClient.scrapPose(poseID: originalPose.id) }))
                }
                .cancellable(id: CancelID.scrap(pose.id), cancelInFlight: true)
                
                return scrapEffect
                
            case let .pageChanged(newID):
                state.selectedID = newID
                return .none
                
            case .didTapBackButton:
                return .run { _ in await dismiss() }
                
                // MARK: - Internal Actions
            case .scrapResponse(_, .success):
                return .run { _ in analytics.logEvent(PoseAnalyticsEvent.poseBookmark) }
                
            case let .scrapResponse(originalPose, .failure(error)):
                if error is CancellationError { return .none }
                Logger.presentation.error("Error occured while scrapping pose: ID-\(originalPose.id) / Error: \(error)")
                
                if state.poses[id: originalPose.id] != nil {
                    state.poses[id: originalPose.id] = originalPose
                    return .send(.delegate(.poseUpdated(originalPose)))
                }
                
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}
