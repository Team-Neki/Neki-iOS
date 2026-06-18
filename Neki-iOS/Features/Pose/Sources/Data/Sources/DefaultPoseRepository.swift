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

public final actor DefaultPoseRepository {
    private var cache: [PoseID: Pose] = [:]
    private var cachedPoseIDsByPeopleCount: [PeopleCountOption: Set<PoseID>] = [:]
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
        cache[id]
    }
    
    /// 캐시 정책을 적용하여 데이터를 병합합니다.
    /// - Parameters:
    ///   - newPose: 네트워크에서 가져온 새 포즈 데이터
    ///   - preserved: `true`일 경우 로컬의 상태(스크랩 여부 등)를 유지하고, `false`일 경우 새 데이터로 덮어씁니다.
    func cacheOrUpdate(_ newPose: Pose, preserved: Bool = false) -> Pose {
        guard let cachedPose = cache[newPose.id] else {
            updateCachedPose(newPose)
            return newPose
        }
        
        guard preserved else {
            updateCachedPose(newPose, replacing: cachedPose)
            return newPose
        }
        
        var merged = newPose
        merged.isScrapped = cachedPose.isScrapped
        updateCachedPose(merged, replacing: cachedPose)
        return merged
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
        let handled = cacheOrUpdate(pose, preserved: true)

        if let currentIndex = currentRandomPoseIndex,
           currentIndex < randomPoseHistoryIDs.index(before: randomPoseHistoryIDs.endIndex) { randomPoseHistoryIDs.removeSubrange(randomPoseHistoryIDs.index(after: currentIndex)..<randomPoseHistoryIDs.endIndex) }

        randomPoseHistoryIDs.append(handled.id)
        currentRandomPoseIndex = randomPoseHistoryIDs.index(before: randomPoseHistoryIDs.endIndex)
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
            let cachedPoses = cache
            guard cachedPoses.isEmpty == false else { throw error }
            
            let countMatchedIDs = cachedPoseIDsByPeopleCount[peopleCount] ?? []
            let validCachedPoses = countMatchedIDs.lazy
                .filter { excludedIDs.contains($0) == false }
                .compactMap { cachedPoses[$0] }
            
            if let randomFallbackPose = validCachedPoses.randomElement() {
                return randomFallbackPose
            } else {
                guard let fallbackID = countMatchedIDs.randomElement(),
                      let fallback = cachedPoses[fallbackID]
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

    func updateCachedPose(_ pose: Pose, replacing oldPose: Pose? = nil) {
        if let oldPose, oldPose.peopleCountOption != pose.peopleCountOption { removeCachedPoseID(pose.id, from: oldPose.peopleCountOption) }
        cache[pose.id] = pose
        cachedPoseIDsByPeopleCount[pose.peopleCountOption, default: []].insert(pose.id)
    }

    func removeCachedPoseID(_ poseID: PoseID, from peopleCount: PeopleCountOption?) {
        guard let peopleCount else { return }
        cachedPoseIDsByPeopleCount[peopleCount]?.remove(poseID)
        if cachedPoseIDsByPeopleCount[peopleCount]?.isEmpty == true { cachedPoseIDsByPeopleCount[peopleCount] = nil }
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
        
        let handled = poses.map { pose in
            var pose = pose
            pose.isScrapped = true
            updateCachedPose(pose)
            return pose
        }
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
                if var rolledBack = cache[poseID] {
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
