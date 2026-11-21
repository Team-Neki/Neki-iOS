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
    /// 이번 랜덤 포즈 화면에서 더 받을 포즈가 없습니다. 서버가 남은 포즈가 없다고 답한 뒤에 씁니다.
    case noMoreRandomPose
}

public typealias PoseID = Int
public typealias PageID = Int

public protocol PoseRepository {
    func fetchPoseList(page: PageID, pageSize: Int, filter: PoseListFilter, refresh: Bool) async throws -> PoseListPage
    func fetchScrappedPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> PoseListPage
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
