//
//  PoseClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation
import ComposableArchitecture

@DependencyClient
public struct PoseClient {
    public var fetchPoseList: @Sendable (_ page: Int, _ pageSize: Int, _ refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool)
    public var fetchScrappedPoseList: @Sendable (_ page: Int, _ pageSize: Int, _ refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool)
    public var fetchPoseDetail: @Sendable (_ id: PoseID) async throws -> Pose
    public var scrapPose: @Sendable (_ poseID: Int) async throws -> Void
    public var initializeRandomPose: @Sendable (_ peopleCount: PeopleCountOption) async throws -> Pose
    public var startRandomPoseSuggestion: @Sendable (_ direction: RandomPosePagingDirection) async throws -> Pose
    public var stopRandomPoseSuggestion: @Sendable () async -> Void
}


// MARK: - PoseClient + DependencyKey

extension PoseClient: DependencyKey {
    public static var liveValue: PoseClient = {
        @Dependency(\.poseRepository) var poseRepository
        
        return PoseClient { page, pageSize, refresh in
            try await poseRepository.fetchPoseList(page: page, pageSize: pageSize, refresh: refresh)
        } fetchScrappedPoseList: { page, pageSize, refresh in
            try await poseRepository.fetchScrappedPoseList(page: page, pageSize: pageSize, refresh: refresh)
        } fetchPoseDetail: { id in
            try await poseRepository.fetchPoseDetail(id: id)
        } scrapPose: { poseID in
            try await poseRepository.scrapPose(poseID: poseID)
        } initializeRandomPose: { peopleCount in
            try await poseRepository.initializeRandomPoseBuffer(peopleCount: peopleCount)
        } startRandomPoseSuggestion: { direction in
            switch direction {
            case .left: return try await poseRepository.fetchPreviousRandomPose()
            case .right: return try await poseRepository.fetchNextRandomPose()
            }
        } stopRandomPoseSuggestion: {
            await poseRepository.flushRandomPoseBuffer()
        }
    }()
}


// MARK: - PoseClient + Dependency Accessor

public extension DependencyValues {
    var poseClient: PoseClient {
        get { self[PoseClient.self] }
        set { self[PoseClient.self] = newValue }
    }
}
