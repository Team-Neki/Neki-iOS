//
//  PoseRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation
import Dependencies
import DependenciesMacros

public enum PoseRepositoryError: Error {
    case noHistory
    case networkError(NetworkError)
}

public typealias PoseID = Int
public typealias PageID = Int

public protocol PoseRepository {
    func fetchPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool)
    func fetchScrappedPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool)
    func fetchPoseDetail(id: PoseID) async throws -> Pose
    func scrapPose(poseID: PoseID) async throws
    func initializeRandomPoseBuffer(peopleCount: PeopleCountOption) async throws -> Pose
    func flushRandomPoseBuffer() async
    func fetchNextRandomPose() async throws -> Pose
    func fetchPreviousRandomPose() async throws -> Pose
}

private enum PoseRepositoryKey: DependencyKey {
    static let liveValue: PoseRepository = {
        DefaultPoseRepository()
    }()
}

extension DependencyValues {
    var poseRepository: PoseRepository {
        get { self[PoseRepositoryKey.self] }
        set { self[PoseRepositoryKey.self] = newValue }
    }
}
