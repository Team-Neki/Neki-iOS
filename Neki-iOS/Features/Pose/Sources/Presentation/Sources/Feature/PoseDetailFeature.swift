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
        case scrapResponse(PoseID, Result<Void, Error>)
        
        // Delegate Actions
        case poseUpdated(Pose)
    }
    
    private enum CancelID: Hashable {
        case scrap(PoseID)
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onTapScrap:
                guard var pose = state.currentPose else { return .none }
                pose.isScrapped.toggle()
                state.poses[id: pose.id] = pose
                return .run { [pose] send in
                    await send(.scrapResponse(pose.id, Result { try await poseClient.scrapPose(poseID: pose.id) }))
                }
                .cancellable(id: CancelID.scrap(pose.id), cancelInFlight: true)
                
            case let .pageChanged(newID):
                state.selectedID = newID
                return .none
                
            case let .scrapResponse(id, .failure(error)):
                Logger.presentation.error("Error occured while scrapping pose: ID-\(id) / Error: \(error)")
                // TODO: 토스트 띄우기?
                return .none
                
            case .didTapBackButton:
                return .run { _ in await dismiss() }
                
            default:
                return .none
            }
        }
    }
}
