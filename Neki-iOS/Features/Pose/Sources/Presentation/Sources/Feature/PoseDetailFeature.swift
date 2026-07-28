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

        init(
            poses: IdentifiedArrayOf<Pose>,
            selectedID: PoseID
        ) {
            self.poses = poses
            self.selectedID = selectedID
        }

        init(
            poses: IdentifiedArrayOf<Pose>,
            selectedPose: Pose
        ) {
            self.poses = poses
            self.selectedID = selectedPose.id
            updatePose(selectedPose)
        }

        mutating func updatePose(_ pose: Pose) {
            if poses[id: pose.id] == nil {
                poses.append(pose)
            } else {
                poses[id: pose.id] = pose
            }
        }
    }
    
    enum Action {
        // Lifecycle Actions
        case onAppear

        // User Actions
        case onTapScrap
        case pageChanged(PoseID)
        case didTapBackButton
        
        // Internal Actions
        case poseDetailResponse(PoseID, Result<Pose, Error>)
        case scrapResponse(Pose, Result<Void, Error>)
        
        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case poseUpdated(Pose)
        }
    }
    
    private enum CancelID: Hashable {
        case detail
        case scrap(PoseID)
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - Lifecycle Actions
            case .onAppear:
                return fetchPoseDetail(id: state.selectedID)

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
                return fetchPoseDetail(id: newID)
                
            case .didTapBackButton:
                return .run { _ in await dismiss() }
                
                // MARK: - Internal Actions
            case let .poseDetailResponse(requestID, .success(pose)):
                guard state.selectedID == requestID || state.poses[id: pose.id] != nil else { return .none }
                state.updatePose(pose)
                return .send(.delegate(.poseUpdated(pose)))

            case let .poseDetailResponse(requestID, .failure(error)):
                if error is CancellationError { return .none }
                Logger.presentation.error("Error occured while fetching pose detail: ID-\(requestID) / Error: \(error)")
                return .none

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

private extension PoseDetailFeature {
    func fetchPoseDetail(id: PoseID) -> Effect<Action> {
        .run { send in
            await send(.poseDetailResponse(id, Result {
                try await poseClient.fetchPoseDetail(id)
            }))
        }
        .cancellable(id: CancelID.detail, cancelInFlight: true)
    }
}
