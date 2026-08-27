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

private enum TileSystem {
    static let defaultZoomLevel: Int = 15
    
    /// 특정 Bounds(화면 영역)에 걸쳐 있는 모든 Tile 리스트를 계산합니다.
    static func getTiles(in bounds: GeographicBoundingBox, zoom: Int = defaultZoomLevel) -> [MapTile] {
        let minTile = convert(coordinate: .init(latitude: bounds.maxLatitude, longitude: bounds.minLongitude), zoom: zoom)
        let maxTile = convert(coordinate: .init(latitude: bounds.minLatitude, longitude: bounds.maxLongitude), zoom: zoom)
        
        var tiles: [MapTile] = []
        for x in minTile.x...maxTile.x {
            for y in minTile.y...maxTile.y {
                tiles.append(MapTile(x: x, y: y, z: zoom))
            }
        }
        return tiles
    }
    
    /// 단일 좌표를 타일 좌표로 변환합니다.
    static func convert(coordinate: GeographicCoordinate, zoom: Int) -> MapTile {
        let n = pow(2.0, Double(zoom))
        let x = Int((coordinate.longitude + 180.0) / 360.0 * n)
        
        let latRad = coordinate.latitude * .pi / 180.0
        let y = Int((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * n)
        
        return MapTile(x: x, y: y, z: zoom)
    }
    
    /// 타일 하나가 커버하는 지리적 영역(BoundingBox)을 계산합니다.
    static func getBoundingBox(for tile: MapTile) -> GeographicBoundingBox {
        let n = pow(2.0, Double(tile.z))
        
        let west = Double(tile.x) / n * 360.0 - 180.0
        let east = Double(tile.x + 1) / n * 360.0 - 180.0
        
        let northRad = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y) / n)))
        let southRad = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y + 1) / n)))
        
        let north = northRad * 180.0 / .pi
        let south = southRad * 180.0 / .pi
        
        return GeographicBoundingBox(minLatitude: south, minLongitude: west, maxLatitude: north, maxLongitude: east)
    }
}

public final actor DefaultPhotoBoothRepository {
    typealias BrandID = String

    private struct TileFetchRequest {
        let task: Task<[PhotoBooth], Error>
        var waiterIDs: Set<UUID>
        var didCacheResult: Bool = false
    }
    
    @Dependency(\.networkProvider) private var networkProvider
    
    private let tileCache: PhotoBoothTileCache
    private let cacheFreshnessPolicy: any PhotoBoothCacheFreshnessPolicy
    private var tileFetchRequests: [MapTile: TileFetchRequest] = [:]
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
        cacheFreshnessPolicy = configuration.freshnessPolicy
        tileCache = PhotoBoothTileCache(configuration: configuration)
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
                
                let requiredTiles = TileSystem.getTiles(in: bounds)
                let now = Date.now
                var tilesToFetch: [MapTile] = []
                var stalePhotoBoothsByTile: [MapTile: [PhotoBooth]] = [:]
                
                // 신선한 캐시는 즉시 반환하고 만료된 캐시는 타일별 갱신 요청이 실패한 경우에만 fallback으로 활용
                var cachedBooths: [PhotoBooth] = []
                for tile in requiredTiles {
                    switch tileCache.lookup(tile: tile, now: now) {
                    case let .fresh(snapshot): cachedBooths.append(contentsOf: photoBoothsApplyingFavoriteState(snapshot.photoBooths))
                    case let .stale(snapshot):
                        stalePhotoBoothsByTile[tile] = snapshot.photoBooths
                        tilesToFetch.append(tile)
                    case .missing: tilesToFetch.append(tile)
                    }
                }
                
                if !cachedBooths.isEmpty {
                    continuation.yield(cachedBooths)
                }
                
                if tilesToFetch.isEmpty == false {
                    try Task.checkCancellation()
                    let staleFallbackByTile = stalePhotoBoothsByTile
                    var firstFetchError: Error?
                    var resolvedTileCount = requiredTiles.count - tilesToFetch.count
                    
                    try await withThrowingTaskGroup(of: [PhotoBooth].self) { group in
                        for tile in tilesToFetch {
                            group.addTask {
                                do {
                                    let photoBooths = try await self.fetchPhotoBooths(for: tile, brands: brands)
                                    try Task.checkCancellation()
                                    return photoBooths
                                } catch is CancellationError {
                                    throw CancellationError()
                                } catch {
                                    guard let stalePhotoBooths = staleFallbackByTile[tile] else { throw error }
                                    return stalePhotoBooths
                                }
                            }
                        }
                        
                        while let result = await group.nextResult() {
                            switch result {
                            case let .success(photoBooths):
                                resolvedTileCount += 1
                                continuation.yield(self.photoBoothsApplyingFavoriteState(photoBooths))
                            case let .failure(error):
                                if error is CancellationError { throw CancellationError() }
                                if firstFetchError == nil { firstFetchError = error }
                            }
                        }

                        guard resolvedTileCount > .zero else { throw firstFetchError ?? NetworkError.responseError }
                    }
                }
                
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
        for tile: MapTile,
        brands: [BrandID: PhotoBoothBrand]
    ) async throws -> [PhotoBooth] {
        try Task.checkCancellation()
        if case let .fresh(snapshot) = tileCache.lookup(tile: tile, now: .now) { return snapshot.photoBooths }

        let waiterID = UUID()
        let task: Task<[PhotoBooth], Error>
        if var request = tileFetchRequests[tile] {
            request.waiterIDs.insert(waiterID)
            tileFetchRequests[tile] = request
            task = request.task
        } else {
            task = makeTileFetchTask(tile: tile, brands: brands)
            tileFetchRequests[tile] = TileFetchRequest(task: task, waiterIDs: [waiterID])
        }

        return try await withTaskCancellationHandler {
            do {
                let photoBooths = try await task.value
                try Task.checkCancellation()
                finishWaitingForTile(tile: tile, waiterID: waiterID, photoBooths: photoBooths)
                return photoBooths
            } catch {
                finishWaitingForTile(tile: tile, waiterID: waiterID)
                throw error
            }
        } onCancel: {
            Task { await self.cancelWaitingForTile(tile: tile, waiterID: waiterID) }
        }
    }

    func makeTileFetchTask(
        tile: MapTile,
        brands: [BrandID: PhotoBoothBrand]
    ) -> Task<[PhotoBooth], Error> {
        Task { [networkProvider] in
            try Task.checkCancellation()
            let tileBounds = TileSystem.getBoundingBox(for: tile)
            let requestDTO = FetchPhotoBoothsDTO.Request(bounds: tileBounds)
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
    }

    func finishWaitingForTile(
        tile: MapTile,
        waiterID: UUID,
        photoBooths: [PhotoBooth]? = nil
    ) {
        guard var request = tileFetchRequests[tile], request.waiterIDs.remove(waiterID) != nil else { return }
        if let photoBooths, request.didCacheResult == false {
            tileCache.insert(
                photoBooths,
                for: tile,
                metadata: PhotoBoothCacheMetadata(cachedAt: .now, validationToken: nil)
            )
            request.didCacheResult = true
        }
        tileFetchRequests[tile] = request.waiterIDs.isEmpty ? nil : request
    }

    func cancelWaitingForTile(tile: MapTile, waiterID: UUID) {
        guard var request = tileFetchRequests[tile], request.waiterIDs.remove(waiterID) != nil else { return }
        guard request.waiterIDs.isEmpty else {
            tileFetchRequests[tile] = request
            return
        }
        request.task.cancel()
        tileFetchRequests[tile] = nil
    }

    func updateCachedBrands(
        _ brands: [BrandID: PhotoBoothBrand],
        orderIDs: [PhotoBoothBrand.ID]?,
        cachedAt: Date
    ) {
        if let brandMap, brandMap != brands { tileCache.removeAll() }
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
