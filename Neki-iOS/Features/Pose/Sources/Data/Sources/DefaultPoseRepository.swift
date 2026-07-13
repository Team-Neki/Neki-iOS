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

private struct Page {
    let poseIDs: [PoseID]
    let hasNext: Bool
}

private struct PoseEntityCache {
    private var posesByID: [PoseID: Pose] = [:]
    private var poseIDsByPeopleCount: [PeopleCountOption: Set<PoseID>] = [:]
    private var accessOrder: [PoseID] = []
    private let maxCount: Int

    var isEmpty: Bool { posesByID.isEmpty }

    init(maxCount: Int) {
        self.maxCount = max(1, maxCount)
    }

    mutating func value(for id: PoseID) -> Pose? {
        guard let pose = posesByID[id] else { return nil }
        markAccessed(id)
        return pose
    }

    func ids(for peopleCount: PeopleCountOption) -> Set<PoseID> {
        poseIDsByPeopleCount[peopleCount] ?? []
    }

    func contains(_ id: PoseID) -> Bool {
        posesByID[id] != nil
    }

    mutating func values(for ids: [PoseID]) -> [Pose]? {
        var poses: [Pose] = []
        poses.reserveCapacity(ids.count)

        for id in ids {
            guard let pose = value(for: id) else { return nil }
            poses.append(pose)
        }

        return poses
    }

    mutating func insertOrUpdate(_ pose: Pose, preservingScrap: Bool) -> Pose {
        guard let cachedPose = posesByID[pose.id] else {
            insert(pose)
            return pose
        }

        var handled = pose
        if preservingScrap { handled.isScrapped = cachedPose.isScrapped }
        if cachedPose.peopleCountOption != handled.peopleCountOption {
            removeID(handled.id, from: cachedPose.peopleCountOption)
        }
        insert(handled)
        return handled
    }

    mutating func trim(protectedIDs: Set<PoseID>) -> Set<PoseID> {
        var removedIDs = Set<PoseID>()

        while posesByID.count > maxCount {
            guard let removableID = accessOrder.first(where: { protectedIDs.contains($0) == false }) else { break }
            remove(removableID)
            removedIDs.insert(removableID)
        }

        return removedIDs
    }

    private mutating func insert(_ pose: Pose) {
        posesByID[pose.id] = pose
        poseIDsByPeopleCount[pose.peopleCountOption, default: []].insert(pose.id)
        markAccessed(pose.id)
    }

    private mutating func remove(_ id: PoseID) {
        guard let pose = posesByID.removeValue(forKey: id) else { return }
        removeID(id, from: pose.peopleCountOption)
        accessOrder.removeAll { $0 == id }
    }

    private mutating func removeID(_ id: PoseID, from peopleCount: PeopleCountOption) {
        poseIDsByPeopleCount[peopleCount]?.remove(id)
        if poseIDsByPeopleCount[peopleCount]?.isEmpty == true { poseIDsByPeopleCount[peopleCount] = nil }
    }

    private mutating func markAccessed(_ id: PoseID) {
        accessOrder.removeAll { $0 == id }
        accessOrder.append(id)
    }
}

public final actor DefaultPoseRepository {
    private var cache = PoseEntityCache(maxCount: 300)
    private var generalPages: [PageID: Page] = [:]
    private var scrappedPages: [PageID: Page] = [:]
    private var activeRandomPosePeopleCount: PeopleCountOption = .solo
    private var randomPoseHistoryIDs: [PoseID] = []
    private var currentRandomPoseIndex: Int?
    private var randomPosePrefetchTask: Task<Pose, Error>?
    private var randomPoseRequestSequence: Int = .zero
    private var randomPoseCommitSequence: Int = .zero
    private var pendingRandomPoseTasks: [Int: Task<Pose, Error>] = [:]
    private var committedRandomPoseIDs: [Int: PoseID] = [:]
    private var scrapTasks: [PoseID: Task<Void, Error>] = [:]
    
    private let maxRetryCount: Int = 3
    private let maxCachedPagesPerScope: Int = 5
    private let maxRandomHistoryCount: Int = 50
    
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
    
    func cachedPose(id: PoseID) -> Pose? {
        cache.value(for: id)
    }
    
    /// 캐시 정책을 적용하여 데이터를 병합합니다.
    /// - Parameters:
    ///   - newPose: 네트워크에서 가져온 새 포즈 데이터
    ///   - preserved: `true`일 경우 로컬의 상태(스크랩 여부 등)를 유지하고, `false`일 경우 새 데이터로 덮어씁니다.
    func cacheOrUpdate(_ newPose: Pose, preserved: Bool = false, trimAfterInsert: Bool = true) -> Pose {
        let handled = cache.insertOrUpdate(newPose, preservingScrap: preserved)
        if trimAfterInsert { trimPoseCacheIfNeeded() }
        return handled
    }
    
    func startRandomPosePrefetchIfNeeded() {
        guard randomPosePrefetchTask == nil else { return }
        let peopleCount = activeRandomPosePeopleCount
        let excludedIDs = recentPoseIDs(limit: maxRetryCount)
        randomPosePrefetchTask = Task { [weak self] in
            guard let self else { throw PoseRepositoryError.noHistory }
            return try await self.fetchRandomPose(
                peopleCount: peopleCount,
                excluding: excludedIDs
            )
        }
    }

    func appendRandomPoseToHistory(_ pose: Pose) -> Pose {
        let handled = cacheOrUpdate(pose, preserved: true, trimAfterInsert: false)

        if let currentIndex = currentRandomPoseIndex,
           currentIndex < randomPoseHistoryIDs.index(before: randomPoseHistoryIDs.endIndex) { randomPoseHistoryIDs.removeSubrange(randomPoseHistoryIDs.index(after: currentIndex)..<randomPoseHistoryIDs.endIndex) }

        randomPoseHistoryIDs.append(handled.id)
        trimRandomPoseHistoryIfNeeded()
        currentRandomPoseIndex = randomPoseHistoryIDs.index(before: randomPoseHistoryIDs.endIndex)
        trimPoseCacheIfNeeded()
        return handled
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
    
    func fetchRandomPose(
        peopleCount: PeopleCountOption,
        excluding excludedIDs: Set<PoseID>
    ) async throws -> Pose {
        let peopleCountValue = convertToRawValue(peopleCount)
        let endpoint = PoseEndpoint.fetchRandomPose(peopleCount: peopleCountValue)
        
        @Sendable func requestSinglePose() async throws -> Pose {
            try Task.checkCancellation()
            let responseDTO: BaseResponseDTO<PoseDTO> = try await networkProvider.request(endpoint: endpoint)
            try Task.checkCancellation()
            guard let newPose = responseDTO.data?.toEntity() else { throw PoseRepositoryError.networkError(.responseDecodingError) }
            return newPose
        }
        
        do {
            let firstPose = try await requestSinglePose()
            if excludedIDs.contains(firstPose.id) == false { return firstPose }
            
            return try await withThrowingTaskGroup(of: Pose.self) { group in
                for _ in 0..<maxRetryCount {
                    group.addTask { try await requestSinglePose() }
                }
                
                for try await pose in group {
                    guard excludedIDs.contains(pose.id) == false else { continue }
                    group.cancelAll()
                    return pose
                }
                
                Logger.data.debug("All parallel retries were duplicates. Fallback to cache.")
                throw PoseRepositoryError.noHistory
            }
        } catch {
            Logger.data.error("Random Pose Fetch Failed or Duplicated: \(error)")
            guard cache.isEmpty == false else { throw error }
            
            let countMatchedIDs = cache.ids(for: peopleCount)
            var validCachedPoses: [Pose] = []
            validCachedPoses.reserveCapacity(countMatchedIDs.count)
            countMatchedIDs.forEach {
                guard excludedIDs.contains($0) == false,
                      let pose = cache.value(for: $0)
                else { return }
                validCachedPoses.append(pose)
            }
            
            if let randomFallbackPose = validCachedPoses.randomElement() {
                return randomFallbackPose
            } else {
                guard let fallbackID = countMatchedIDs.randomElement(),
                      let fallback = cache.value(for: fallbackID)
                else { throw error }
                return fallback
            }
            
        }
    }
    
    func recentPoseIDs(limit: Int) -> Set<PoseID> {
        guard let currentIndex = currentRandomPoseIndex else { return [] }
        let lowerBound = max(randomPoseHistoryIDs.startIndex, currentIndex - limit)
        return Set(randomPoseHistoryIDs[lowerBound...currentIndex])
    }

    func resetRandomPoseBuffer() {
        pendingRandomPoseTasks.values.forEach { $0.cancel() }
        pendingRandomPoseTasks.removeAll(keepingCapacity: true)
        committedRandomPoseIDs.removeAll(keepingCapacity: true)
        randomPoseRequestSequence = .zero
        randomPoseCommitSequence = .zero
        randomPosePrefetchTask?.cancel()
        randomPosePrefetchTask = nil
        randomPoseHistoryIDs.removeAll(keepingCapacity: true)
        currentRandomPoseIndex = nil
    }

    func updateCachedPose(_ pose: Pose) {
        cache.insertOrUpdate(pose, preservingScrap: false)
        trimPoseCacheIfNeeded()
    }

    func trimPoseCacheIfNeeded() {
        removeStaleReferences()
        let removedIDs = cache.trim(protectedIDs: protectedPoseIDs())
        guard removedIDs.isEmpty == false else { return }
        removeEvictedReferences(removedIDs)
    }

    func protectedPoseIDs() -> Set<PoseID> {
        var protectedIDs = Set<PoseID>()
        scrapTasks.keys.forEach { if cache.contains($0) { protectedIDs.insert($0) } }
        randomPoseHistoryIDs.forEach { if cache.contains($0) { protectedIDs.insert($0) } }
        committedRandomPoseIDs.values.forEach { if cache.contains($0) { protectedIDs.insert($0) } }
        return protectedIDs
    }

    func removeStaleReferences() {
        removePagesContainingMissingCachedPose()
        removeStaleRandomPoseReferences()
    }

    func removePagesContainingMissingCachedPose() {
        for (pageID, page) in generalPages {
            guard page.poseIDs.contains(where: { cache.contains($0) == false }) else { continue }
            generalPages[pageID] = nil
        }

        for (pageID, page) in scrappedPages {
            guard page.poseIDs.contains(where: { cache.contains($0) == false }) else { continue }
            scrappedPages[pageID] = nil
        }
    }

    func removeStaleRandomPoseReferences() {
        let currentPoseID = currentRandomPoseIndex.flatMap { randomPoseHistoryIDs.indices.contains($0) ? randomPoseHistoryIDs[$0] : nil }
        randomPoseHistoryIDs = randomPoseHistoryIDs.filter { cache.contains($0) }

        if let currentPoseID, let currentIndex = randomPoseHistoryIDs.firstIndex(of: currentPoseID) {
            currentRandomPoseIndex = currentIndex
        } else {
            currentRandomPoseIndex = randomPoseHistoryIDs.indices.last
        }

        committedRandomPoseIDs = committedRandomPoseIDs.filter { cache.contains($0.value) }
    }

    func removeEvictedReferences(_ removedIDs: Set<PoseID>) {
        for (pageID, page) in generalPages {
            guard page.poseIDs.contains(where: { removedIDs.contains($0) }) else { continue }
            generalPages[pageID] = nil
        }

        for (pageID, page) in scrappedPages {
            guard page.poseIDs.contains(where: { removedIDs.contains($0) }) else { continue }
            scrappedPages[pageID] = nil
        }

        let currentPoseID = currentRandomPoseIndex.flatMap { randomPoseHistoryIDs.indices.contains($0) ? randomPoseHistoryIDs[$0] : nil }
        randomPoseHistoryIDs = randomPoseHistoryIDs.filter { removedIDs.contains($0) == false }

        if let currentPoseID, let currentIndex = randomPoseHistoryIDs.firstIndex(of: currentPoseID) {
            currentRandomPoseIndex = currentIndex
        } else {
            currentRandomPoseIndex = randomPoseHistoryIDs.indices.last
        }
        committedRandomPoseIDs = committedRandomPoseIDs.filter { removedIDs.contains($0.value) == false }
    }

    func trimGeneralPagesIfNeeded() {
        guard generalPages.count > maxCachedPagesPerScope else { return }
        let removablePageIDs = generalPages.keys.sorted().prefix(generalPages.count - maxCachedPagesPerScope)
        removablePageIDs.forEach { generalPages[$0] = nil }
        trimPoseCacheIfNeeded()
    }

    func trimScrappedPagesIfNeeded() {
        guard scrappedPages.count > maxCachedPagesPerScope else { return }
        let removablePageIDs = scrappedPages.keys.sorted().prefix(scrappedPages.count - maxCachedPagesPerScope)
        removablePageIDs.forEach { scrappedPages[$0] = nil }
        trimPoseCacheIfNeeded()
    }

    func trimRandomPoseHistoryIfNeeded() {
        guard randomPoseHistoryIDs.count > maxRandomHistoryCount,
              let currentIndex = currentRandomPoseIndex
        else { return }

        let overflowCount = randomPoseHistoryIDs.count - maxRandomHistoryCount
        let removableCount = min(overflowCount, currentIndex)
        guard removableCount > .zero else { return }
        randomPoseHistoryIDs.removeFirst(removableCount)
        currentRandomPoseIndex = currentIndex - removableCount
        trimCommittedRandomPoseIDs()
    }

    func trimCommittedRandomPoseIDs() {
        let minimumSequence = max(.zero, randomPoseCommitSequence - maxRandomHistoryCount)
        committedRandomPoseIDs = committedRandomPoseIDs.filter { $0.key >= minimumSequence }
    }

    func cachedPageResponse(_ page: Page?) -> (poses: [Pose], hasNext: Bool)? {
        guard let page,
              let poses = cache.values(for: page.poseIDs)
        else { return nil }
        return (poses, page.hasNext)
    }

    func initializeRandomPoseHistory(peopleCount: PeopleCountOption) async throws -> Pose {
        activeRandomPosePeopleCount = peopleCount
        randomPosePrefetchTask?.cancel()
        randomPosePrefetchTask = nil
        randomPoseHistoryIDs.removeAll(keepingCapacity: true)
        currentRandomPoseIndex = nil

        let pose = try await fetchRandomPose(peopleCount: peopleCount, excluding: [])
        let handled = appendRandomPoseToHistory(pose)
        startRandomPosePrefetchIfNeeded()
        return handled
    }

    func makeRandomPoseTask(peopleCount: PeopleCountOption) -> Task<Pose, Error> {
        if let task = randomPosePrefetchTask {
            randomPosePrefetchTask = nil
            return task
        }

        let excludedIDs = recentPoseIDs(limit: maxRetryCount)
        return Task { [weak self] in
            guard let self else { throw PoseRepositoryError.noHistory }
            return try await self.fetchRandomPose(
                peopleCount: peopleCount,
                excluding: excludedIDs
            )
        }
    }

    func fetchReplacementIfNeeded(_ pose: Pose, peopleCount: PeopleCountOption) async throws -> Pose {
        var candidate = pose
        var retryCount: Int = .zero

        while recentPoseIDs(limit: maxRetryCount).contains(candidate.id), retryCount < maxRetryCount {
            retryCount += 1
            candidate = try await fetchRandomPose(
                peopleCount: peopleCount,
                excluding: recentPoseIDs(limit: maxRetryCount)
            )
        }

        return candidate
    }
}


// MARK: - DefaultPoseRepository + PoseRepository

extension DefaultPoseRepository: PoseRepository {
    public func fetchPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool) {
        if refresh { generalPages.removeAll() }
        else if let cachedResponse = cachedPageResponse(generalPages[page]) { return cachedResponse }
        
        let endpoint = PoseEndpoint.fetchPoseList(page: page, size: pageSize, peopleCount: nil, sortBy: nil)
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let items = responseDTO.data?.items ?? []
        let hasNext = responseDTO.data?.hasNext ?? false
        
        var handled: [Pose] = []
        var poseIDs: [PoseID] = []
        handled.reserveCapacity(items.count)
        poseIDs.reserveCapacity(items.count)
        items.forEach {
            let pose = cacheOrUpdate($0.toEntity(), preserved: true, trimAfterInsert: false)
            handled.append(pose)
            poseIDs.append(pose.id)
        }
        generalPages[page] = Page(poseIDs: poseIDs, hasNext: hasNext)
        trimGeneralPagesIfNeeded()
        return (handled, hasNext)
    }
    
    public func fetchScrappedPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> (poses: [Pose], hasNext: Bool) {
        if refresh { scrappedPages.removeAll() }
        else if let cachedResponse = cachedPageResponse(scrappedPages[page]) { return cachedResponse }
        
        let endpoint = PoseEndpoint.fetchScrappedPoseList(page: page, size: pageSize, sortBy: nil)
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let items = responseDTO.data?.items ?? []
        let hasNext = responseDTO.data?.hasNext ?? false
        
        var handled: [Pose] = []
        var poseIDs: [PoseID] = []
        handled.reserveCapacity(items.count)
        poseIDs.reserveCapacity(items.count)
        items.forEach {
            var pose = $0.toEntity()
            pose.isScrapped = true
            cacheOrUpdate(pose, trimAfterInsert: false)
            handled.append(pose)
            poseIDs.append(pose.id)
        }
        scrappedPages[page] = Page(poseIDs: poseIDs, hasNext: hasNext)
        trimScrappedPagesIfNeeded()
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
        guard var pose = cachedPose(id: poseID) else { return }
        scrapTasks[pose.id]?.cancel()
        
        let originalState = pose.isScrapped
        let newState = originalState == false
        pose.isScrapped = newState
        updateCachedPose(pose)
        
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
                if var rolledBack = cachedPose(id: poseID) {
                    rolledBack.isScrapped = originalState
                    updateCachedPose(rolledBack)
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
        return try await initializeRandomPoseHistory(peopleCount: peopleCount)
    }
    
    public func flushRandomPoseBuffer() async {
        resetRandomPoseBuffer()
    }
    
    public func fetchNextRandomPose() async throws -> Pose {
        try Task.checkCancellation()
        guard let currentIndex = currentRandomPoseIndex else { return try await initializeRandomPoseHistory(peopleCount: activeRandomPosePeopleCount) }

        let nextIndex = randomPoseHistoryIDs.index(after: currentIndex)
        if pendingRandomPoseTasks.isEmpty,
           randomPoseHistoryIDs.indices.contains(nextIndex),
           let pose = cachedPose(id: randomPoseHistoryIDs[nextIndex]) {
            currentRandomPoseIndex = nextIndex
            startRandomPosePrefetchIfNeeded()
            return pose
        }

        let peopleCount = activeRandomPosePeopleCount
        randomPoseRequestSequence += 1
        let sequence = randomPoseRequestSequence
        pendingRandomPoseTasks[sequence] = makeRandomPoseTask(peopleCount: peopleCount)

        while randomPoseCommitSequence < sequence {
            let nextSequence = randomPoseCommitSequence + 1

            if let committedPoseID = committedRandomPoseIDs[sequence],
               let committedPose = cachedPose(id: committedPoseID) {
                return committedPose
            }

            guard let task = pendingRandomPoseTasks[nextSequence] else {
                randomPoseCommitSequence = nextSequence
                guard nextSequence != sequence else { throw PoseRepositoryError.noHistory }
                continue
            }

            let pose: Pose
            do {
                pose = try await task.value
            } catch {
                pendingRandomPoseTasks[nextSequence] = nil
                randomPoseCommitSequence = nextSequence
                guard nextSequence != sequence else { throw error }
                continue
            }

            guard pendingRandomPoseTasks[nextSequence] != nil else { continue }

            pendingRandomPoseTasks[nextSequence] = nil
            let uniquePose: Pose
            do {
                uniquePose = try await fetchReplacementIfNeeded(
                    pose,
                    peopleCount: peopleCount
                )
            } catch {
                randomPoseCommitSequence = nextSequence
                guard nextSequence != sequence else { throw error }
                continue
            }
            let handled = appendRandomPoseToHistory(uniquePose)
            committedRandomPoseIDs[nextSequence] = handled.id
            randomPoseCommitSequence = nextSequence
            trimCommittedRandomPoseIDs()
            startRandomPosePrefetchIfNeeded()

            guard nextSequence != sequence else { return handled }
        }

        guard let poseID = committedRandomPoseIDs[sequence],
              let pose = cachedPose(id: poseID)
        else {
            throw PoseRepositoryError.noHistory
        }
        return pose
    }
    
    public func fetchPreviousRandomPose() async throws -> Pose {
        guard let currentIndex = currentRandomPoseIndex,
              currentIndex > randomPoseHistoryIDs.startIndex
        else {
            throw PoseRepositoryError.noHistory
        }

        let previousIndex = randomPoseHistoryIDs.index(before: currentIndex)
        guard let pose = cachedPose(id: randomPoseHistoryIDs[previousIndex]) else { throw PoseRepositoryError.noHistory }

        currentRandomPoseIndex = previousIndex
        startRandomPosePrefetchIfNeeded()
        return pose
    }
}
