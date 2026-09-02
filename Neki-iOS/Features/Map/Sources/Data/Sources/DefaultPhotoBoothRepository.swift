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
}


// MARK: - DefaultPhotoBoothRepository + Cache Helpers

private extension DefaultPhotoBoothRepository {
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
