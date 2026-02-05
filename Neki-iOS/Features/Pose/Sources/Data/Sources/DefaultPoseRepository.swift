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
    var pose: Pose
    var next: RandomPoseNode?
    var previous: RandomPoseNode?
    
    init(pose: Pose) { self.pose = pose }
}

private struct Page {
    let poseIDs: [PoseID]
    let hasNext: Bool
}

public final actor DefaultPoseRepository {
    private var cache: [PoseID: Pose] = [:]
    private var generalPages: [PageID: Page] = [:]
    private var scrappedPages: [PageID: Page] = [:]
    private var activeRandomPosePeopleCount: PeopleCountOption = .solo
    private var currentRandomNode: RandomPoseNode?
    private var scrapTasks: [PoseID: Task<Void, Error>] = [:]
    
    private let maxRetryCount: Int = 7
    
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
    
    func syncNodeWithCache(_ node: RandomPoseNode) -> Pose {
        guard let cached = cache[node.pose.id] else { return node.pose }
        node.pose = cached; return cached
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
        
        guard preserved else {
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
        let recentIDs = checkRecentPoseIDs(limit: maxRetryCount)
        
        do {
            let newPose = try await fetchRandomPose(excluding: recentIDs)
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
    
    /// 스크랩 목록에서 캐시를 갱신합니다. (스크랩 등록 또는 취소 시)
    /// - Parameters:
    ///     - poseID: 대상 포즈 식별자
    ///     - isScrapped: `true`면 목록의 끝에 추가, `false`면 목록에서 제거
    func updateScrappedPagesCache(poseID: PoseID, isScrapped: Bool) {
        guard isScrapped else {
            for (pageID, page) in scrappedPages {
                guard let index = page.poseIDs.firstIndex(of: poseID) else { continue }
                var currentIDs = page.poseIDs
                currentIDs.remove(at: index)
                scrappedPages[pageID] = Page(poseIDs: currentIDs, hasNext: page.hasNext)
            }
            return
        }
        
        guard scrappedPages.isEmpty == false, let lastPageID = scrappedPages.keys.max(), let lastPage = scrappedPages[lastPageID], lastPage.poseIDs.contains(poseID) == false else { return }
        var currentIDs = lastPage.poseIDs
        currentIDs.append(poseID)
        scrappedPages[lastPageID] = Page(poseIDs: currentIDs, hasNext: lastPage.hasNext)
    }
    
    func fetchRandomPose(retryCount: Int = .zero, excluding excludedIDs: Set<PoseID>) async throws -> Pose {
        let peopleCountValue = convertToRawValue(activeRandomPosePeopleCount)
        let endpoint = PoseEndpoint.fetchRandomPose(peopleCount: peopleCountValue)
        
        do {
            let responseDTO: BaseResponseDTO<PoseDTO> = try await networkProvider.request(endpoint: endpoint)
            
            guard let newPose = responseDTO.data?.toEntity() else { throw PoseRepositoryError.networkError(.responseDecodingError) }
            
            guard excludedIDs.contains(newPose.id) == false else {
                if retryCount < maxRetryCount {
                    return try await fetchRandomPose(retryCount: retryCount + 1, excluding: excludedIDs)
                } else {
                    Logger.data.debug("Max retries reached. Returning duplicate pose.")
                    return newPose
                }
            }
            return newPose
        } catch {
            Logger.data.error("Random Pose Fetch Failed: \(error)")
            guard cache.isEmpty == false else { throw error }
            let validCachedPoses = cache.values.filter { excludedIDs.contains($0.id) == false }
            
            if let randomFallbackPose = validCachedPoses.randomElement() {
                return randomFallbackPose
            } else {
                guard let anyCached = cache.values.randomElement() else { throw error }
                return anyCached
            }
        }
    }
    
    func checkRecentPoseIDs(limit: Int) -> Set<PoseID> {
        var ids: Set<PoseID> = []
        var currentNode = currentRandomNode
        var count: Int = .zero
        
        if let current = currentNode { ids.insert(current.pose.id) }
        
        while let previous = currentNode?.previous, count < limit {
            ids.insert(previous.pose.id)
            currentNode = previous
            count += 1
        }
        
        return ids
    }
}


// MARK: - DefaultPoseRepository + PoseRepository

extension DefaultPoseRepository: PoseRepository {
    public func fetchPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool) {
        if refresh { generalPages.removeAll() }
        else if let cachedPage = generalPages[page] { return (cachedPage.poseIDs.compactMap { cache[$0] }, cachedPage.hasNext) }
        
        let endpoint = PoseEndpoint.fetchPoseList(page: page, size: pageSize, peopleCount: nil, sortBy: nil)
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let poses = responseDTO.data?.items.compactMap { $0.toEntity() } ?? []
        let hasNext = responseDTO.data?.hasNext ?? false
        
        let handled = poses.map { cacheOrUpdate($0, preserved: true) }
        generalPages[page] = Page(poseIDs: handled.map(\.id), hasNext: hasNext)
        return (handled, hasNext)
    }
    
    public func fetchScrappedPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool) {
        if refresh { scrappedPages.removeAll() }
        else if let cachedPage = scrappedPages[page] { return (cachedPage.poseIDs.compactMap { cache[$0] }, cachedPage.hasNext) }
        
        let endpoint = PoseEndpoint.fetchScrappedPoseList(page: page, size: pageSize, sortBy: nil)
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let poses = responseDTO.data?.items.compactMap { $0.toEntity() } ?? []
        let hasNext = responseDTO.data?.hasNext ?? false
        
        let handled = poses.map { var pose = $0; pose.isScrapped = true; cache[pose.id] = pose; return pose }
        scrappedPages[page] = Page(poseIDs: handled.map(\.id), hasNext: hasNext)
        return (handled, hasNext)
    }
    
    public func fetchPoseDetail(id: PoseID) async throws -> Pose {
        let endpoint = PoseEndpoint.fetchPoseDetail(poseID: id)
        let responseDTO: BaseResponseDTO<PoseDTO> = try await networkProvider.request(endpoint: endpoint)
        guard let pose = responseDTO.data?.toEntity() else { throw PoseRepositoryError.networkError(.responseDecodingError) }
        let handled = cacheOrUpdate(pose)
        return handled
    }
    
    public func scrapPose(poseID: PoseID) async throws {
        guard var pose = cache[poseID] else { return }
        scrapTasks[pose.id]?.cancel()
        
        let originalState = pose.isScrapped
        let newState = originalState == false
        pose.isScrapped = newState
        cache[poseID] = pose
        
        updateScrappedPagesCache(poseID: poseID, isScrapped: newState)
        
        let task = Task {
            do {
                let requestDTO = ScrapPoseDTO.Request(toBe: newState)
                let endpoint = PoseEndpoint.scrapPose(poseID: poseID, dto: requestDTO)
                let _: BaseResponseDTO<ScrapPoseDTO.Response> = try await networkProvider.request(endpoint: endpoint)
                scrapTasks[pose.id] = nil
            } catch {
                if error is CancellationError { return }
                scrapTasks[pose.id] = nil
                if var rolledBack = cache[poseID] {
                    rolledBack.isScrapped = originalState
                    cache[poseID] = rolledBack
                }
                updateScrappedPagesCache(poseID: poseID, isScrapped: originalState)
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
            return syncNodeWithCache(nextNode)
        }
        
        let recentIDs = checkRecentPoseIDs(limit: maxRetryCount)
        let handled = try await fetchRandomPose(excluding: recentIDs)
        let cachedPose = cacheOrUpdate(handled)
        
        guard let existingNext = currentNode.next else {
            appendNode(cachedPose, to: currentNode)
            currentRandomNode = currentNode.next
            return cachedPose
        }
        
        appendNode(cachedPose, to: existingNext)
        currentRandomNode = existingNext
        return existingNext.pose
    }
    
    public func fetchPreviousRandomPose() async throws -> Pose {
        guard let previous = currentRandomNode?.previous else { throw PoseRepositoryError.noHistory }
        currentRandomNode = previous
        return syncNodeWithCache(previous)
    }
}
