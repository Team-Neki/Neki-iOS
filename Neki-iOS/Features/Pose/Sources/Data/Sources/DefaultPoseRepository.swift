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
    let totalCount: Int?
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

    @discardableResult
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

    mutating func randomValue(for peopleCount: PeopleCountOption, excluding excludedIDs: Set<PoseID>) -> Pose? {
        guard let ids = poseIDsByPeopleCount[peopleCount], ids.isEmpty == false else { return nil }

        var fallbackID: PoseID?
        var fallbackCount: Int = .zero
        var validID: PoseID?
        var validCount: Int = .zero

        ids.forEach {
            guard posesByID[$0] != nil else { return }
            fallbackCount += 1
            if Int.random(in: 0..<fallbackCount) == .zero { fallbackID = $0 }
            guard excludedIDs.contains($0) == false else { return }
            validCount += 1
            if Int.random(in: 0..<validCount) == .zero { validID = $0 }
        }

        if let validID { return value(for: validID) }
        guard let fallbackID else { return nil }
        return value(for: fallbackID)
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
    /// 조건마다 받은 페이지입니다. 조건이 다른 목록끼리 섞이지 않게 나눠 둡니다.
    private var generalPages: [PoseListFilter: [PageID: Page]] = [:]
    private var scrappedPages: [PageID: Page] = [:]
    private var activeRandomPosePeopleCount: PeopleCountOption = .solo
    private var randomPoseHistoryIDs: [PoseID] = []
    private var currentRandomPoseIndex: Int?
    private var randomPosePrefetchTask: Task<Pose, Error>?
    private var randomPoseRequestSequence: Int = .zero
    private var randomPoseCommitSequence: Int = .zero
    private var pendingRandomPoseTasks: [Int: Task<Pose, Error>] = [:]
    private var committedRandomPoseIDs: [Int: PoseID] = [:]
    /// 이번 랜덤 포즈 화면에서 보여 준 포즈입니다. 본 지 오래된 포즈가 앞에 오고, 다시 보여 주면 맨 뒤로 옮깁니다.
    /// 기록은 50장까지만 남고 앞으로 갔다가 새 포즈를 받으면 뒤가 잘리므로, 기록과 따로 둡니다.
    private var shownRandomPoseIDs: [PoseID] = []
    /// 서버가 남은 포즈가 없다고 답했는지입니다. 켜지면 이 화면을 닫을 때까지 랜덤 포즈를 다시 묻지 않습니다.
    private var isRandomPoseExhausted: Bool = false
    private var scrapTasks: [PoseID: Task<Void, Error>] = [:]
    
    private let maxRetryCount: Int = 3
    private let maxCachedPagesPerScope: Int = 5
    private let maxRandomHistoryCount: Int = 50
    /// 포즈 목록을 최신순(등록일 내림차순)으로 명시해 요청하는 `sort` 값입니다. 화면의 "최신순"이 서버 기본 정렬에 기대지 않게 합니다.
    private let latestFirstSort: String = "LATEST"
    /// 북마크 목록을 최신순으로 요청하는 `sortOrder` 값입니다. 북마크 목록 API는 정렬 기준 없이 방향만 받습니다.
    private let latestFirstSortOrder: String = "DESC"
    /// 제외할 포즈를 빼면 남은 랜덤 포즈가 없을 때, 서버가 400과 함께 보내는 결과 코드입니다.
    private let noMoreRandomPoseResultCode: String = "D-09"
    
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
    
    func convertToRawValue(_ relation: PoseRelation) -> String {
        switch relation {
        case .friend: return "FRIEND"
        case .couple: return "COUPLE"
        case .crush: return "SSUM"
        }
    }
    
    func cachedPose(id: PoseID) -> Pose? {
        cache.value(for: id)
    }
    
    /// 캐시 정책을 적용하여 데이터를 병합합니다.
    /// - Parameters:
    ///   - newPose: 네트워크에서 가져온 새 포즈 데이터
    ///   - preserved: `true`일 경우 로컬의 상태(스크랩 여부 등)를 유지하고, `false`일 경우 새 데이터로 덮어씁니다.
    @discardableResult
    func cacheOrUpdate(_ newPose: Pose, preserved: Bool = false, trimAfterInsert: Bool = true) -> Pose {
        let handled = cache.insertOrUpdate(newPose, preservingScrap: preserved)
        if trimAfterInsert { trimPoseCacheIfNeeded() }
        return handled
    }
    
    func startRandomPosePrefetchIfNeeded() {
        guard randomPosePrefetchTask == nil, isRandomPoseExhausted == false else { return }
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
        markRandomPoseShown(handled.id)
        trimPoseCacheIfNeeded()
        return handled
    }
    
    /// 진행 중인 북마크 요청이 모두 끝날 때까지 기다립니다. 요청이 실패해도 기다리기만 합니다.
    func waitForPendingScrapRequests() async {
        for task in Array(scrapTasks.values) { _ = await task.result }
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
                scrappedPages[pageID] = Page(poseIDs: currentIDs, hasNext: page.hasNext, totalCount: page.totalCount)
            }
            return
        }
        
        guard scrappedPages.isEmpty == false, let lastPageID = scrappedPages.keys.max(), let lastPage = scrappedPages[lastPageID], lastPage.poseIDs.contains(poseID) == false else { return }
        var currentIDs = lastPage.poseIDs
        currentIDs.append(poseID)
        scrappedPages[lastPageID] = Page(poseIDs: currentIDs, hasNext: lastPage.hasNext, totalCount: lastPage.totalCount)
    }
    
    func fetchRandomPose(
        peopleCount: PeopleCountOption,
        excluding excludedIDs: Set<PoseID>
    ) async throws -> Pose {
        // 남은 포즈가 없다는 답을 받은 뒤에는 이 화면을 닫을 때까지 서버에 묻지 않습니다.
        guard isRandomPoseExhausted == false else { throw PoseRepositoryError.noMoreRandomPose }
        let peopleCountValue = convertToRawValue(peopleCount)
        // 최근 본 포즈를 제외 ID로 보내 서버가 그 포즈를 빼고 고르게 합니다.
        // 서버가 제외를 지키지 않거나 요청이 실패할 때를 위해 아래의 겹침 확인과 앱 메모리 대체는 그대로 둡니다.
        let endpoint = PoseEndpoint.fetchRandomPose(peopleCount: peopleCountValue, excludedPoseIDs: excludedIDs.sorted())
        
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
            if isNoMoreRandomPoseError(error) {
                // 닫힌 화면의 늦은 응답이 새 화면을 멈추지 않게, 취소된 요청이면 표시를 켜지 않습니다.
                try Task.checkCancellation()
                Logger.data.debug("No more random poses. Stop requesting until the random pose screen closes.")
                isRandomPoseExhausted = true
                throw PoseRepositoryError.noMoreRandomPose
            }
            Logger.data.error("Random Pose Fetch Failed or Duplicated: \(error)")
            guard cache.isEmpty == false else { throw error }
            
            guard let fallback = cache.randomValue(for: peopleCount, excluding: excludedIDs) else { throw error }
            return fallback
            
        }
    }
    
    func recentPoseIDs(limit: Int) -> Set<PoseID> {
        guard let currentIndex = currentRandomPoseIndex else { return [] }
        let lowerBound = max(randomPoseHistoryIDs.startIndex, currentIndex - limit)
        return Set(randomPoseHistoryIDs[lowerBound...currentIndex])
    }

    /// 이번 화면에서 보여 준 포즈로 남깁니다. 이미 있으면 맨 뒤로 옮겨, 본 지 오래된 순서를 지킵니다.
    func markRandomPoseShown(_ id: PoseID) {
        shownRandomPoseIDs.removeAll { $0 == id }
        shownRandomPoseIDs.append(id)
    }

    /// 남은 포즈가 없을 때 대신 보여 줄 포즈입니다. 이번 화면에서 본 포즈 중 지금 포즈가 아니고 본 지 가장 오래된 포즈를 고릅니다.
    func leastRecentlyShownRandomPose() -> Pose? {
        let currentPoseID = currentRandomPoseIndex.flatMap { randomPoseHistoryIDs.indices.contains($0) ? randomPoseHistoryIDs[$0] : nil }
        for id in shownRandomPoseIDs where id != currentPoseID {
            if let pose = cachedPose(id: id) { return pose }
        }
        return nil
    }

    /// 서버가 남은 랜덤 포즈가 없다고 답한 오류인지 봅니다. 사진 정보 없음(`D-04`) 같은 다른 400과 구분합니다.
    func isNoMoreRandomPoseError(_ error: Error) -> Bool {
        guard case let NetworkError.badRequestError(resultCode) = error else { return false }
        return resultCode == noMoreRandomPoseResultCode
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
        shownRandomPoseIDs.removeAll(keepingCapacity: true)
        isRandomPoseExhausted = false
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
        for (filter, pages) in generalPages {
            for (pageID, page) in pages {
                guard page.poseIDs.contains(where: { cache.contains($0) == false }) else { continue }
                generalPages[filter]?[pageID] = nil
            }
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
        for (filter, pages) in generalPages {
            for (pageID, page) in pages {
                guard page.poseIDs.contains(where: { removedIDs.contains($0) }) else { continue }
                generalPages[filter]?[pageID] = nil
            }
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

    func trimGeneralPagesIfNeeded(for filter: PoseListFilter) {
        guard let pages = generalPages[filter], pages.count > maxCachedPagesPerScope else { return }
        let removablePageIDs = pages.keys.sorted().prefix(pages.count - maxCachedPagesPerScope)
        removablePageIDs.forEach { generalPages[filter]?[$0] = nil }
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

    func cachedPageResponse(_ page: Page?) -> PoseListPage? {
        guard let page,
              let poses = cache.values(for: page.poseIDs)
        else { return nil }
        return PoseListPage(poses: poses, hasNext: page.hasNext, totalCount: page.totalCount)
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
    public func fetchPoseList(page: PageID, pageSize: Int, filter: PoseListFilter, refresh: Bool) async throws -> PoseListPage {
        if refresh { generalPages.removeAll() }
        else if let cachedResponse = cachedPageResponse(generalPages[filter]?[page]) { return cachedResponse }
        
        let endpoint = PoseEndpoint.fetchPoseList(
            page: page,
            size: pageSize,
            peopleCount: filter.peopleCount.map(convertToRawValue),
            relation: filter.relation.map(convertToRawValue),
            sortBy: latestFirstSort
        )
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let items = responseDTO.data?.items ?? []
        let hasNext = responseDTO.data?.hasNext ?? false
        let totalCount = responseDTO.data?.totalCount
        
        var handled: [Pose] = []
        var poseIDs: [PoseID] = []
        handled.reserveCapacity(items.count)
        poseIDs.reserveCapacity(items.count)
        items.forEach {
            let pose = cacheOrUpdate($0.toEntity(), preserved: true, trimAfterInsert: false)
            handled.append(pose)
            poseIDs.append(pose.id)
        }
        generalPages[filter, default: [:]][page] = Page(poseIDs: poseIDs, hasNext: hasNext, totalCount: totalCount)
        trimGeneralPagesIfNeeded(for: filter)
        return PoseListPage(poses: handled, hasNext: hasNext, totalCount: totalCount)
    }
    
    public func fetchScrappedPoseList(page: PageID, pageSize: Int, refresh: Bool) async throws -> PoseListPage {
        if refresh { scrappedPages.removeAll() }
        else if let cachedResponse = cachedPageResponse(scrappedPages[page]) { return cachedResponse }
        
        // 북마크 요청이 서버에 닿기 전에 목록을 받으면 방금 누른 북마크가 빠지거나 해제한 포즈가 다시 오므로, 진행 중인 북마크 요청이 끝난 뒤 받습니다.
        await waitForPendingScrapRequests()
        let endpoint = PoseEndpoint.fetchScrappedPoseList(page: page, size: pageSize, sortBy: latestFirstSortOrder)
        let responseDTO: BaseResponseDTO<PoseListDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let items = responseDTO.data?.items ?? []
        let hasNext = responseDTO.data?.hasNext ?? false
        let totalCount = responseDTO.data?.totalCount
        
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
        scrappedPages[page] = Page(poseIDs: poseIDs, hasNext: hasNext, totalCount: totalCount)
        trimScrappedPagesIfNeeded()
        return PoseListPage(poses: handled, hasNext: hasNext, totalCount: totalCount)
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
            markRandomPoseShown(pose.id)
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

            // 남은 포즈가 없다는 답이면 `nil`로 받아, 아래에서 이번 화면에서 본 포즈 중에서 고릅니다.
            let fetchedPose: Pose?
            do {
                fetchedPose = try await task.value
            } catch PoseRepositoryError.noMoreRandomPose {
                fetchedPose = nil
            } catch {
                pendingRandomPoseTasks[nextSequence] = nil
                randomPoseCommitSequence = nextSequence
                guard nextSequence != sequence else { throw error }
                continue
            }

            guard pendingRandomPoseTasks[nextSequence] != nil else { continue }

            pendingRandomPoseTasks[nextSequence] = nil
            let uniquePose: Pose?
            do {
                if let fetchedPose {
                    uniquePose = try await fetchReplacementIfNeeded(
                        fetchedPose,
                        peopleCount: peopleCount
                    )
                } else {
                    uniquePose = nil
                }
            } catch PoseRepositoryError.noMoreRandomPose {
                uniquePose = nil
            } catch {
                randomPoseCommitSequence = nextSequence
                guard nextSequence != sequence else { throw error }
                continue
            }
            // 고르기와 기록에 더하기 사이에 기다림이 없어, 빠르게 여러 번 넘겨도 같은 포즈를 연달아 고르지 않습니다.
            guard let nextPose = uniquePose ?? leastRecentlyShownRandomPose() else {
                randomPoseCommitSequence = nextSequence
                guard nextSequence != sequence else { throw PoseRepositoryError.noMoreRandomPose }
                continue
            }
            let handled = appendRandomPoseToHistory(nextPose)
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
        markRandomPoseShown(pose.id)
        startRandomPosePrefetchIfNeeded()
        return pose
    }
}
