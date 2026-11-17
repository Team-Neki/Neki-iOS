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
        /// 그리드 목록을 이어 넘기는 상세인지입니다.
        ///
        /// 그리드에서 연 상세는 끝 가까이 넘기면 다음 페이지를 요청하고, 그리드 목록이 받은 포즈를 끝에 붙입니다.
        /// 랜덤 포즈에서 연 상세는 그 랜덤 포즈가 목록에 없으면 목록 끝에 붙여 열기 때문에, 그 뒤로 그리드 목록을 잇지 않습니다.
        let followsList: Bool
        var currentPose: Pose? { poses[id: selectedID] }
        var isScrapped: Bool { currentPose?.isScrapped ?? false }

        /// 지금 포즈 뒤에 남은 포즈가 이 수 이하가 되면 다음 페이지를 요청합니다. 한 장씩 넘기므로 끝에 닿기 전에 미리 받습니다.
        static let paginationPrefetchCount = 3
        /// 다음 페이지를 요청할 때인지입니다. 그리드 목록을 이어 넘기는 상세가 끝 가까이에 오면 참입니다.
        var needsMorePoses: Bool {
            guard followsList, let index = poses.index(id: selectedID) else { return false }
            return poses.count - 1 - index <= Self.paginationPrefetchCount
        }

        init(
            poses: IdentifiedArrayOf<Pose>,
            selectedID: PoseID,
            followsList: Bool
        ) {
            self.poses = poses
            self.selectedID = selectedID
            self.followsList = followsList
        }

        init(
            poses: IdentifiedArrayOf<Pose>,
            selectedPose: Pose,
            followsList: Bool
        ) {
            self.poses = poses
            self.selectedID = selectedPose.id
            self.followsList = followsList
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
        /// 그리드 목록이 다음 페이지를 받으면 늘어난 목록을 받습니다. 상세에 없는 포즈만 끝에 붙입니다.
        case appendPoses([Pose])
        case poseDetailResponse(PoseID, Result<Pose, Error>)
        case scrapResponse(Pose, Result<Void, Error>)
        
        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            /// 하트를 누르거나 북마크 요청이 실패해 되돌렸을 때 보냅니다.
            case poseUpdated(Pose)
            /// 서버에서 포즈 정보를 받았을 때 보냅니다. 북마크를 바꾼 것이 아니어서 하트 변경과 나눠 알립니다.
            case poseFetched(Pose)
            /// 그리드 목록을 이어 넘기는 상세가 끝 가까이에 오면 보냅니다. 그리드 목록이 다음 페이지를 받습니다.
            case requestMorePoses
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
                return .merge(fetchPoseDetail(id: state.selectedID), requestMorePosesIfNeeded(state))

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
                let trackingEffect: Effect<Action> = .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseBookmark) }
                
                return .merge(scrapEffect, trackingEffect)
                
            case let .pageChanged(newID):
                state.selectedID = newID
                return .merge(fetchPoseDetail(id: newID), requestMorePosesIfNeeded(state))
                
            case .didTapBackButton:
                return .run { _ in await dismiss() }
                
                // MARK: - Internal Actions
            case let .appendPoses(poses):
                guard state.followsList else { return .none }
                // 이미 있는 포즈는 건너뛰므로, 북마크를 해제해 그리드 목록에서 빠진 포즈도 상세에서는 제자리에 남습니다.
                state.poses.append(contentsOf: poses)
                // 붙인 포즈가 적어 아직 끝 가까이면 다시 요청합니다. 마지막 페이지까지 받았으면 그리드 목록이 더 받지 않습니다.
                return requestMorePosesIfNeeded(state)
                
            case let .poseDetailResponse(requestID, .success(pose)):
                guard state.selectedID == requestID || state.poses[id: pose.id] != nil else { return .none }
                state.updatePose(pose)
                return .send(.delegate(.poseFetched(pose)))

            case let .poseDetailResponse(requestID, .failure(error)):
                if error is CancellationError { return .none }
                Logger.presentation.error("Error occured while fetching pose detail: ID-\(requestID) / Error: \(error)")
                return .none

            case .scrapResponse(_, .success):
                return .none
                
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
    
    /// 다음 페이지를 요청할 때면 그리드 목록에 요청합니다.
    func requestMorePosesIfNeeded(_ state: State) -> Effect<Action> {
        state.needsMorePoses ? .send(.delegate(.requestMorePoses)) : .none
    }
}
