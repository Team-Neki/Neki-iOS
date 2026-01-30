//
//  DefaultPoseRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation
import Dependencies
import DependenciesMacros
import os

private final class RandomPoseNode {
    let pose: Pose
    var next: RandomPoseNode?
    var previous: RandomPoseNode?
    
    init(pose: Pose) { self.pose = pose }
}

public final actor DefaultPoseRepository {
    private var cache: [PoseID: Pose] = [:]
    private var pageIDs: [PageID: [PoseID]] = [:]
    private var activeRandomPosePeopleCount: PeopleCountOption = .solo
    private var currentRandomNode: RandomPoseNode?
    private var scrapTasks: [PoseID: Task<Void, Error>] = [:]
    
    @Dependency(\.networkProvider) private var networkProvider
    
    public init() {}
}


// MARK: - DefaultPoseRepository + Helpers

private extension DefaultPoseRepository {
    func convertToRawValue(_ option: PeopleCountOption) -> String {
        switch option {
        case .solo: return "ONE"
        case .duo: return "TWO"
        case .trio: return "THREE"
        case .quartet: return "FOUR"
        case .overQuartet: return "FIVE_OR_MORE"
        }
    }
    
    /// 캐시 정책을 적용하여 데이터를 병합합니다.
    /// - Parameters:
    ///   - newPose: 네트워크에서 가져온 새 포즈 데이터
    ///   - preserved: `true`일 경우 로컬의 상태(스크랩 여부 등)를 유지하고, `false`일 경우 새 데이터로 덮어씁니다.
    func cacheOrUpdate(_ newPose: Pose, preserved: Bool = false) -> Pose {
        guard let cachedPose = cache[newPose.id] else {
            cache[newPose.id] = newPose
            return newPose
        }
        
        if preserved == false {
            cache[newPose.id] = newPose
            return newPose
        }
        
        var merged = newPose
        merged.isScrapped = cachedPose.isScrapped
        cache[newPose.id] = merged
        return merged
    }
    
    func prefetchNext(from node: RandomPoseNode) async throws {
        guard node.next == nil else { return }
        let peopleCountValue: String = convertToRawValue(activeRandomPosePeopleCount)
        let endpoint = PoseEndpoint.fetchRandomPose(peopleCount: peopleCountValue)
        
        do {
            let responseDTO: BaseResponseDTO<PoseDTO> = try await networkProvider.request(endpoint: endpoint)
            guard let newPose = responseDTO.data?.toEntity() else { throw PoseRepositoryError.networkError(.responseDecodingError) }
            let handled = cacheOrUpdate(newPose)
            appendNode(handled, to: node)
        } catch {
            Logger.data.error("Random Pose Prefetching Failed: \(error)")
        }
    }
    
    func appendNode(_ pose: Pose, to previous: RandomPoseNode) {
        guard previous.next == nil else { return }
        let newNode = RandomPoseNode(pose: pose)
        previous.next = newNode
        newNode.previous = previous
    }
}


// MARK: - DefaultPoseRepository + PoseRepository

extension DefaultPoseRepository: PoseRepository {
    public func fetchPoseList(page: PageID, pageSize: Int) async throws -> [Pose] {
        if let ids = pageIDs[page] { return ids.compactMap { cache[$0] } }
        
        let endpoint = PoseEndpoint.fetchPoseList(page: page, size: pageSize, peopleCount: nil, sortBy: nil)
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let poses = responseDTO.data?.items.compactMap { $0.toEntity() } ?? []
        let handled = poses.map { cacheOrUpdate($0, preserved: true) }
        pageIDs[page] = handled.map(\.id)
        return handled
    }
    
    public func fetchScrappedPoseList(page: PageID, pageSize: Int) async throws -> [Pose] {
        let endpoint = PoseEndpoint.fetchScrappedPoseList(page: page, size: pageSize, sortBy: nil)
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let poses = responseDTO.data?.items.compactMap { $0.toEntity() } ?? []
        let handled = poses.map { var pose = $0; pose.isScrapped = true; cache[pose.id] = pose; return pose }
        return handled
    }
    
    public func fetchPoseDetail(id: PoseID) async throws -> Pose {
        let endpoint = PoseEndpoint.fetchPoseDetail(poseID: id)
        let responseDTO: BaseResponseDTO<PoseDTO> = try await networkProvider.request(endpoint: endpoint)
        guard let pose = responseDTO.data?.toEntity() else { throw PoseRepositoryError.networkError(.responseDecodingError) }
        let handled = cacheOrUpdate(pose)
        return pose
    }
    
    public func scrapPose(poseID: PoseID) async throws {
        guard var pose = cache[poseID] else { return }
        scrapTasks[pose.id]?.cancel()
        
        let originalState = pose.isScrapped
        let newState = originalState == false
        pose.isScrapped = newState
        cache[poseID] = pose
        
        let task = Task {
            do {
                let requestDTO = ScrapPoseDTO.Request(toBe: newState)
                let endpoint = PoseEndpoint.scrapPose(poseID: poseID, dto: requestDTO)
                let _: BaseResponseDTO<ScrapPoseDTO.Response> = try await networkProvider.request(endpoint: endpoint)
                scrapTasks[pose.id] = nil
            } catch {
                if error is CancellationError { return }
                if var rolledBack = cache[poseID] {
                    rolledBack.isScrapped = originalState
                    cache[poseID] = rolledBack
                }
                throw error
            }
        }
        
        scrapTasks[poseID] = task
        try await task.value
    }
    
    public func initializeRandomPoseBuffer(peopleCount: PeopleCountOption) async throws -> Pose {
        await flushRandomPoseBuffer()
        
        activeRandomPosePeopleCount = peopleCount
        let peopleCountValue = convertToRawValue(peopleCount)
        let endpoint = PoseEndpoint.fetchRandomPose(peopleCount: peopleCountValue)
        async let request: BaseResponseDTO<PoseDTO> = networkProvider.request(endpoint: endpoint)
        async let requestSpare: BaseResponseDTO<PoseDTO> = networkProvider.request(endpoint: endpoint)
        
        let (requestDTO, requestDTOSpare) = try await (request, requestSpare)
        guard let pose = requestDTO.data?.toEntity(), let poseSpare = requestDTOSpare.data?.toEntity() else { throw PoseRepositoryError.networkError(.responseDecodingError) }
        let node1 = RandomPoseNode(pose: cacheOrUpdate(pose, preserved: true))
        let node2 = RandomPoseNode(pose: cacheOrUpdate(poseSpare, preserved: true))
        node1.next = node2
        node2.previous = node1
        currentRandomNode = node1
        return node1.pose
    }
    
    public func flushRandomPoseBuffer() async {
        guard var node = currentRandomNode else { return }
        
        // 앞으로 가면서 연결 끊기
        var forward = node.next
        while let next = forward {
            node.next = nil
            next.previous = nil
            forward = next.next
            node = next
        }
        
        // 뒤로 가면서 연결 끊기
        node = currentRandomNode!
        var backward = node.previous
        while let prev = backward {
            node.previous = nil
            prev.next = nil
            backward = prev.previous
            node = prev
        }
        
        currentRandomNode = nil
    }
    
    public func fetchNextRandomPose() async throws -> Pose {
        guard let currentNode = currentRandomNode else { return try await initializeRandomPoseBuffer(peopleCount: activeRandomPosePeopleCount) }
        
        if let nextNode = currentNode.next {
            currentRandomNode = nextNode
            Task { [weak self] in try await self?.prefetchNext(from: nextNode) }
            return nextNode.pose
        }
        
        let peopleCountValue = convertToRawValue(activeRandomPosePeopleCount)
        let endpoint = PoseEndpoint.fetchRandomPose(peopleCount: peopleCountValue)
        let responseDTO: BaseResponseDTO<PoseDTO> = try await networkProvider.request(endpoint: endpoint)
        guard let pose = responseDTO.data?.toEntity() else { throw PoseRepositoryError.networkError(.responseDecodingError) }
        let handled = cacheOrUpdate(pose)
        appendNode(handled, to: currentNode)
        currentRandomNode = currentNode.next
        return handled
    }
    
    public func fetchPreviousRandomPose() async throws -> Pose {
        guard let previous = currentRandomNode?.previous else { throw PoseRepositoryError.noHistory }
        currentRandomNode = previous
        return previous.pose
    }
}
