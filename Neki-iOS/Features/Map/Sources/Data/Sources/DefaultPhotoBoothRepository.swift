//
//  DefaultPhotoBoothRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation
import Dependencies
import DependenciesMacros
import os

public final actor DefaultPhotoBoothRepository {
    typealias BrandID = String
    
    @Dependency(\.networkProvider) private var networkProvider
    
    private let regionCache: PhotoBoothRegionCache
    private let cacheFreshnessPolicy: any PhotoBoothCacheFreshnessPolicy
    private var favoritePhotoBoothIDs: [PhotoBooth.ID] = []
    private var favoritePhotoBoothIDSet: Set<PhotoBooth.ID> = []
    private var favoritePhotoBoothsByID: [PhotoBooth.ID: PhotoBooth] = [:]
    private var hasLoadedFavoritePhotoBoothSnapshot: Bool = false
    private var favoriteMutationRevision: UInt = .zero
    private var brandMap: [BrandID: PhotoBoothBrand]?
    private var brandCachedAt: Date?
    private var brandOrderIDs: [PhotoBoothBrand.ID] = []
    private var brandOrderMutationRevision: UInt = .zero
    private var brandFetchTask: Task<[BrandID: PhotoBoothBrand], Error>?
    
    public init() { self.init(configuration: .standard) }
    
    init(configuration: PhotoBoothCacheConfiguration) {
        regionCache = PhotoBoothRegionCache(configuration: configuration)
        cacheFreshnessPolicy = configuration.freshnessPolicy
    }
    
    private func ensureBrandsLoaded() async throws -> [BrandID: PhotoBoothBrand] {
        let now = Date.now
        if let existingMap = brandMap,
           let brandCachedAt,
           cacheFreshnessPolicy.isFresh(
               metadata: PhotoBoothCacheMetadata(cachedAt: brandCachedAt, validationToken: nil),
               now: now
           ) {
            return existingMap
        }
        
        if let existingTask = brandFetchTask {
            do {
                return try await existingTask.value
            } catch {
                if let brandMap { return brandMap }
                throw error
            }
        }
        
        let orderMutationRevision = brandOrderMutationRevision
        let task = Task<[BrandID: PhotoBoothBrand], Error> {
            let endpoint = MapEndpoint.fetchBrands
            let responseDTO: BaseResponseDTO<FetchPhotoBrandsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let brandList = responseDTO.data else { throw NetworkError.responseDecodingError }
            let brandEntities = brandList.map { $0.toEntity() }
            let map = Dictionary(uniqueKeysWithValues: brandEntities.map { ($0.name, $0) })
            let orderIDs = brandEntities.map(\.id)
            let latestOrderIDs = orderMutationRevision == brandOrderMutationRevision ? orderIDs : nil
            updateCachedBrands(map, orderIDs: latestOrderIDs, cachedAt: .now)
            return map
        }
        
        brandFetchTask = task
        
        do {
            let map = try await task.value
            brandFetchTask = nil
            return map
        } catch {
            brandFetchTask = nil
            if let brandMap { return brandMap }
            throw error
        }
    }
}


// MARK: - DefaultPhotoBoothRepository + PhotoBoothRepository

extension DefaultPhotoBoothRepository: PhotoBoothRepository {
    func readPhotoBooths(in bounds: GeographicBoundingBox) -> AsyncThrowingStream<[PhotoBooth], Error> {
        let (stream, continuation) = AsyncThrowingStream<[PhotoBooth], Error>.makeStream()
        let task = Task {
            do {
                try Task.checkCancellation()

                let brands = try await ensureBrandsLoaded()
                
                try Task.checkCancellation()

                let requestedBounds = PhotoBoothQueryBoundsExpander.expandedBounds(for: bounds)
                let now = Date.now
                let staleSnapshot: PhotoBoothRegionCacheSnapshot?
                switch regionCache.lookup(bounds: requestedBounds, now: now) {
                case let .fresh(snapshot):
                    continuation.yield(photoBoothsApplyingFavoriteState(snapshot.photoBooths))
                    continuation.finish()
                    return
                case let .stale(snapshot): staleSnapshot = snapshot
                case .missing: staleSnapshot = nil
                }

                let photoBooths: [PhotoBooth]
                do {
                    photoBooths = try await fetchPhotoBooths(in: requestedBounds, brands: brands)
                    regionCache.insert(
                        photoBooths,
                        for: requestedBounds,
                        metadata: PhotoBoothCacheMetadata(cachedAt: .now, validationToken: nil)
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    guard let staleSnapshot else { throw error }
                    photoBooths = staleSnapshot.photoBooths
                }

                try Task.checkCancellation()
                continuation.yield(photoBoothsApplyingFavoriteState(photoBooths))
                continuation.finish()
                
            } catch is CancellationError {
                Logger.data.debug("Fetching photoBooths stream is cancelled.")
                continuation.finish()
            } catch {
                Logger.data.error("POI Stream error: \(error)")
                continuation.finish(throwing: error)
            }
        }
        
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }
    
    func updatePhotoBoothFavorite(id: Int, isFavorite: Bool) async throws {
        let dto = TogglePhotoBoothFavoriteDTO(favorite: isFavorite)
        let endpoint = MapEndpoint.updateFavorite(id: id, dto: dto)
        let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
        favoriteMutationRevision &+= 1
        updateCachedFavoriteState(id: id, isFavorite: isFavorite)
    }

    func readFavoritePhotoBooths() async throws -> [PhotoBooth] {
        let brands = try await ensureBrandsLoaded()
        let requestRevision = favoriteMutationRevision
        let endpoint = MapEndpoint.fetchFavorites
        let responseDTO: BaseResponseDTO<FetchFavoritePhotoBoothsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        guard let items = responseDTO.data?.items else { throw NetworkError.responseDecodingError }
        let serverFavoriteIDs = items.map(\.id)
        let photoBooths = items.compactMap { dto -> PhotoBooth? in
            guard let brand = brands[dto.brandName] else { return nil }
            var photoBooth = dto.toEntity(brand: brand)
            photoBooth.isFavorite = true
            return photoBooth
        }
        guard requestRevision == favoriteMutationRevision else { return photoBooths }
        updateCachedFavoritePhotoBooths(photoBooths, serverFavoriteIDs: serverFavoriteIDs)
        return favoritePhotoBoothIDs.compactMap { favoritePhotoBoothsByID[$0] }
    }

    func loadBrands() async throws -> [PhotoBoothBrand] {
        let brands = try await ensureBrandsLoaded()
        return orderedBrands(Array(brands.values), by: brandOrderIDs)
    }

    func updateBrandOrder(_ brands: [PhotoBoothBrand]) async throws -> [PhotoBoothBrand] {
        let orderedIDs = brands.map(\.id)
        let dto = UpdatePhotoBoothBrandOrderDTO.Request(brandIDs: orderedIDs)
        let endpoint = MapEndpoint.updateBrandOrder(dto: dto)
        let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
        brandOrderMutationRevision &+= 1
        brandOrderIDs = orderedIDs
        return brands
    }

    func searchCandidates(
        keyword: String,
        type: PhotoBoothSearchCandidateType,
        page: Int,
        size: Int
    ) async throws -> PhotoBoothSearchCandidatePage {
        switch type {
        case .region:
            let endpoint = MapEndpoint.searchRegions(keyword: keyword, page: page, size: size)
            let responseDTO: BaseResponseDTO<SearchRegionsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
            return PhotoBoothSearchCandidatePage(
                type: .region,
                candidates: data.items.map { .region($0.toEntity()) },
                hasNext: data.hasNext
            )

        case .subwayStation:
            let endpoint = MapEndpoint.searchStations(keyword: keyword, page: page, size: size)
            let responseDTO: BaseResponseDTO<SearchStationsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
            return PhotoBoothSearchCandidatePage(
                type: .subwayStation,
                candidates: data.items.map { .subwayStation($0.toEntity()) },
                hasNext: data.hasNext
            )

        case .photoBooth:
            let brands = try await ensureBrandsLoadedByCode()
            let endpoint = MapEndpoint.searchPhotoBooths(keyword: keyword, page: page, size: size)
            let responseDTO: BaseResponseDTO<SearchPhotoBoothsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
            let photoBooths = photoBoothsApplyingFavoriteState(searchPhotoBooths(from: data.items, brands: brands))
            return PhotoBoothSearchCandidatePage(
                type: .photoBooth,
                candidates: photoBooths.map { .photoBooth($0) },
                hasNext: data.hasNext
            )
        }
    }

    func readSearchResultPhotoBooths(
        target: PhotoBoothSearchTarget,
        userCoordinate: GeographicCoordinate?
    ) async throws -> [PhotoBooth] {
        let brands = try await ensureBrandsLoadedByCode()
        let requestDTO = FetchSearchResultPhotoBoothsDTO.Request(target: target, userCoordinate: userCoordinate)
        let endpoint = MapEndpoint.searchResultPhotoBooths(dto: requestDTO)
        let responseDTO: BaseResponseDTO<FetchSearchResultPhotoBoothsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        guard let items = responseDTO.data?.photoBooths else { throw NetworkError.responseDecodingError }
        return photoBoothsApplyingFavoriteState(searchPhotoBooths(from: items, brands: brands))
    }

    func readSearchResultBrandFilters(
        target: PhotoBoothSearchTarget
    ) async throws -> [PhotoBoothSearchBrandFilter] {
        let brands = try await ensureBrandsLoadedByCode()
        // 필터 집계는 거리를 쓰지 않아 서버가 기준 위치를 무시하므로 담지 않습니다.
        let requestDTO = FetchSearchFilterDTO.Request(target: target, userCoordinate: nil)
        let endpoint = MapEndpoint.searchFilter(dto: requestDTO)
        let responseDTO: BaseResponseDTO<FetchSearchFilterDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        guard let items = responseDTO.data?.brandFilters else { throw NetworkError.responseDecodingError }
        return searchBrandFilters(from: items, brands: brands)
    }
}


// MARK: - DefaultPhotoBoothRepository + Cache Helpers

private extension DefaultPhotoBoothRepository {
    /// 브랜드 코드로 조회할 수 있도록 다시 키를 잡은 브랜드 목록입니다.
    ///
    /// 검색 계열 응답은 브랜드명과 함께 코드를 내려주므로, 표기가 바뀔 수 있는 이름 대신 코드로 매칭합니다.
    func ensureBrandsLoadedByCode() async throws -> [String: PhotoBoothBrand] {
        let brands = try await ensureBrandsLoaded()
        return Dictionary(brands.values.map { ($0.englishName, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func searchPhotoBooths(
        from dtos: [SearchPhotoBoothDTO],
        brands: [String: PhotoBoothBrand]
    ) -> [PhotoBooth] {
        dtos.compactMap { dto in
            guard let brand = brands[dto.brandCode] else {
                Logger.data.error("Brand Mapping Failed: '\(dto.brandCode)' not found in brand codes")
                return nil
            }
            return dto.toEntity(brand: brand)
        }
    }

    /// 필터 응답에 없는 브랜드 이미지를 브랜드 전체 조회 결과에서 채웁니다.
    ///
    /// 서버가 사용자별 정렬 순서로 내려주므로 순서를 그대로 유지합니다.
    func searchBrandFilters(
        from dtos: [FetchSearchFilterDTO.Response.BrandFilter],
        brands: [String: PhotoBoothBrand]
    ) -> [PhotoBoothSearchBrandFilter] {
        dtos.compactMap { dto in
            guard let brand = brands[dto.code] else {
                Logger.data.error("Brand Mapping Failed: '\(dto.code)' not found in brand codes")
                return nil
            }
            return PhotoBoothSearchBrandFilter(brand: brand, count: dto.count)
        }
    }

    func photoBoothsApplyingFavoriteState(_ photoBooths: [PhotoBooth]) -> [PhotoBooth] {
        photoBooths.map { photoBooth in
            var updatedPhotoBooth = photoBooth
            let isFavorite = favoritePhotoBoothIDSet.contains(photoBooth.id)
            if hasLoadedFavoritePhotoBoothSnapshot || isFavorite { updatedPhotoBooth.isFavorite = isFavorite }
            return updatedPhotoBooth
        }
    }

    func updateCachedFavoriteState(id: PhotoBooth.ID, isFavorite: Bool) {
        updateFavoritePhotoBoothOrder(id: id, isFavorite: isFavorite)

        if var photoBooth = favoritePhotoBoothsByID[id] {
            photoBooth.isFavorite = isFavorite
            favoritePhotoBoothsByID[id] = isFavorite ? photoBooth : nil
        }
    }

    func updateCachedFavoritePhotoBooths(
        _ photoBooths: [PhotoBooth],
        serverFavoriteIDs: [PhotoBooth.ID]
    ) {
        favoritePhotoBoothIDs = serverFavoriteIDs
        favoritePhotoBoothIDSet = Set(serverFavoriteIDs)
        hasLoadedFavoritePhotoBoothSnapshot = true
        favoritePhotoBoothsByID = photoBooths.reduce(into: [:]) { result, photoBooth in
            var favoriteBooth = photoBooth
            favoriteBooth.isFavorite = true
            result[favoriteBooth.id] = favoriteBooth
        }
    }

    func fetchPhotoBooths(
        in bounds: GeographicBoundingBox,
        brands: [BrandID: PhotoBoothBrand]
    ) async throws -> [PhotoBooth] {
        let requestDTO = FetchPhotoBoothsDTO.Request(bounds: bounds)
        let endpoint = MapEndpoint.polygon(dto: requestDTO)
        let responseDTO: BaseResponseDTO<FetchPhotoBoothsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        guard let items = responseDTO.data?.photoBooths else { throw NetworkError.responseDecodingError }
        return items.compactMap { dto in
            guard let brand = brands[dto.brandName] else {
                Logger.data.error("Brand Mapping Failed: '\(dto.brandName)' not found in brand keys: \(brands.keys)")
                return nil
            }
            return dto.toEntity(brand: brand)
        }
    }

    func updateCachedBrands(
        _ brands: [BrandID: PhotoBoothBrand],
        orderIDs: [PhotoBoothBrand.ID]?,
        cachedAt: Date
    ) {
        if let brandMap, brandMap != brands { regionCache.removeAll() }
        brandMap = brands
        if let orderIDs { brandOrderIDs = orderIDs }
        brandCachedAt = cachedAt
    }

    func updateFavoritePhotoBoothOrder(id: PhotoBooth.ID, isFavorite: Bool) {
        if isFavorite {
            guard favoritePhotoBoothIDSet.insert(id).inserted else { return }
            favoritePhotoBoothIDs.insert(id, at: .zero)
        } else {
            guard favoritePhotoBoothIDSet.remove(id) != nil else { return }
            favoritePhotoBoothIDs.removeAll { $0 == id }
        }
    }

    func orderedBrands(_ brands: [PhotoBoothBrand], by orderIDs: [PhotoBoothBrand.ID]) -> [PhotoBoothBrand] {
        guard orderIDs.isEmpty == false else {
            return brands.sorted { $0.id < $1.id }
        }

        let brandsByID = Dictionary(uniqueKeysWithValues: brands.map { ($0.id, $0) })
        var orderedBrands = orderIDs.compactMap { brandsByID[$0] }
        let orderedIDSet = Set(orderIDs)
        orderedBrands.append(contentsOf: brands.filter { orderedIDSet.contains($0.id) == false }.sorted { $0.id < $1.id })
        return orderedBrands
    }
}
