//
//  DefaultPhotoBoothRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation
import CoreLocation
import Dependencies
import DependenciesMacros
import os

private enum PhotoBoothBrandOrderServerStub {
    // 서버 브랜드 순서 저장 API 준비 전 실기기 검증용입니다.
    // 서버 API 연동 시 이 플래그와 updateBrandOrder의 stub 분기를 제거합니다.
    static let isEnabled = true
}

private enum PhotoBoothFavoriteServerStub {
    // 서버 포토부스 즐겨찾기 API 준비 전 실기기 검증용입니다.
    // 서버 API 연동 시 이 플래그와 updatePhotoBoothFavorite의 stub 분기를 제거합니다.
    static let isEnabled = true
}

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
    
    private struct CachedPhotoBooth {
        var photoBooth: PhotoBooth
        var favoriteOrder: Int?
    }
    
    @Dependency(\.networkProvider) private var networkProvider
    
    private var cache: [MapTile: [PhotoBooth]] = [:]
    private var photoBoothCacheByID: [PhotoBooth.ID: CachedPhotoBooth] = [:]
    private var nextFavoriteOrder: Int = .zero
    private var brandMap: [BrandID: PhotoBoothBrand]?
    private var brandOrderIDs: [PhotoBoothBrand.ID] = []
    private var brandFetchTask: Task<[BrandID: PhotoBoothBrand], Error>?
    
    public init() {}
    
    private func ensureBrandsLoaded() async throws -> [BrandID: PhotoBoothBrand] {
        if let existingMap = brandMap { return existingMap }
        
        if let existingTask = brandFetchTask { return try await existingTask.value }
        
        let task = Task<[BrandID: PhotoBoothBrand], Error> {
            let endpoint = MapEndpoint.fetchBrands
            let responseDTO: BaseResponseDTO<FetchPhotoBrandsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let brandList = responseDTO.data else { return [:] }
            return brandList.reduce(into: [BrandID: PhotoBoothBrand]()) { dict, dto in
                let brandEntity = dto.toEntity()
                dict[brandEntity.name] = brandEntity
            }
        }
        
        brandFetchTask = task
        
        do {
            let map = try await task.value
            if map.isEmpty == false { brandMap = map }
            brandFetchTask = nil
            return map
        } catch {
            brandFetchTask = nil
            throw error
        }
    }
}


// MARK: - DefaultPhotoBoothRepository + PhotoBoothRepository

extension DefaultPhotoBoothRepository: PhotoBoothRepository {
    func readPhotoBooths(in bounds: GeographicBoundingBox) -> AsyncStream<[PhotoBooth]> {
        let (stream, continuation) = AsyncStream<[PhotoBooth]>.makeStream()
        let task = Task {
            do {
                try Task.checkCancellation()

                let brands = try await ensureBrandsLoaded()
                
                try Task.checkCancellation()
                
                let requiredTiles = TileSystem.getTiles(in: bounds)
                let missingTiles = requiredTiles.filter { cache[$0] == nil }
                
                var cachedBooths: [PhotoBooth] = []
                for tile in requiredTiles {
                    if let cached = cache[tile] {
                        cachedBooths.append(contentsOf: cached)
                    }
                }
                
                if !cachedBooths.isEmpty {
                    updateCachedPhotoBooths(cachedBooths)
                    continuation.yield(cachedBooths)
                }
                
                if !missingTiles.isEmpty {
                    try Task.checkCancellation()
                    
                    try await withThrowingTaskGroup(of: (MapTile, [PhotoBooth]).self) { group in
                        for tile in missingTiles {
                            group.addTask { [networkProvider] in
                                try Task.checkCancellation()
                                
                                let tileBounds = TileSystem.getBoundingBox(for: tile)
                                let requestDTO = FetchPhotoBoothsDTO.Request(bounds: tileBounds)
                                let endpoint = MapEndpoint.polygon(dto: requestDTO)
                                let responseDTO: BaseResponseDTO<FetchPhotoBoothsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
                                let photoBooths = responseDTO.data?.photoBooths.compactMap { dto -> PhotoBooth? in
                                    guard let brand = brands[dto.brandName] else {
                                        Logger.data.error("Brand Mapping Failed: '\(dto.brandName)' not found in brand keys: \(brands.keys)")
                                        return nil
                                    }
                                    return dto.toEntity(brand: brand)
                                } ?? []
                                
                                return (tile, photoBooths)
                            }
                        }
                        
                        for try await (tile, booths) in group {
                            self.cache[tile] = booths
                            self.updateCachedPhotoBooths(booths)
                            continuation.yield(booths)
                        }
                    }
                }
                
                continuation.finish()
                
            } catch is CancellationError {
                Logger.data.debug("Fetching photoBooths stream is cancelled.")
                continuation.finish()
            } catch {
                Logger.data.error("POI Stream error: \(error)")
                continuation.finish()
            }
        }
        
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }
    
    func readNearbyPhotoBooths(coordinate: GeographicCoordinate) async throws -> [PhotoBooth] {
        let brands = try await ensureBrandsLoaded()
        let defaultRadius: Int = 1000
        let requestDTO = FetchNearbyPhotoBoothsDTO.Request(longitude: coordinate.longitude, latitude: coordinate.latitude, radiusInMeters: defaultRadius)
        let endpoint = MapEndpoint.point(dto: requestDTO)
        let responseDTO: BaseResponseDTO<FetchNearbyPhotoBoothsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        let photoBooths = responseDTO.data?.photoBooths.compactMap { dto -> PhotoBooth? in
            guard let brand = brands[dto.brandName] else { return nil }
            return dto.toEntity(brand: brand)
        } ?? []
        updateCachedPhotoBooths(photoBooths)
        return photoBooths
    }
    
    func updatePhotoBoothFavorite(id: Int, isFavorite: Bool) async throws {
        if PhotoBoothFavoriteServerStub.isEnabled {
            updateCachedFavoriteState(id: id, isFavorite: isFavorite)
            return
        }

        let dto = TogglePhotoBoothFavoriteDTO(favorite: isFavorite)
        let endpoint = MapEndpoint.updateFavorite(id: id, dto: dto)
        let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
        updateCachedFavoriteState(id: id, isFavorite: isFavorite)
    }

    func readFavoritePhotoBooths() async -> [PhotoBooth] {
        photoBoothCacheByID.values
            .filter { $0.photoBooth.isFavorite }
            .sorted {
                let lhsOrder = $0.favoriteOrder ?? Int.max
                let rhsOrder = $1.favoriteOrder ?? Int.max
                return lhsOrder > rhsOrder
            }
            .map(\.photoBooth)
    }

    func loadBrands() async throws -> [PhotoBoothBrand] {
        let brands = try await ensureBrandsLoaded()
        return Array(brands.values).sorted { $0.id < $1.id }
    }
}


// MARK: - DefaultPhotoBoothRepository + Cache Helpers

private extension DefaultPhotoBoothRepository {
    func updateCachedPhotoBooths(_ photoBooths: [PhotoBooth]) {
        photoBooths.forEach { photoBooth in
            var entry = photoBoothCacheByID[photoBooth.id] ?? CachedPhotoBooth(photoBooth: photoBooth, favoriteOrder: nil)
            entry.photoBooth = photoBooth
            entry.favoriteOrder = updatedFavoriteOrder(currentOrder: entry.favoriteOrder, isFavorite: photoBooth.isFavorite)
            photoBoothCacheByID[photoBooth.id] = entry
        }
    }

    func updateCachedFavoriteState(id: PhotoBooth.ID, isFavorite: Bool) {
        if var entry = photoBoothCacheByID[id] {
            entry.photoBooth.isFavorite = isFavorite
            entry.favoriteOrder = updatedFavoriteOrder(currentOrder: entry.favoriteOrder, isFavorite: isFavorite)
            photoBoothCacheByID[id] = entry
        }

        for tile in cache.keys {
            guard let index = cache[tile]?.firstIndex(where: { $0.id == id }) else { continue }
            cache[tile]?[index].isFavorite = isFavorite
        }
    }

    func updatedFavoriteOrder(currentOrder: Int?, isFavorite: Bool) -> Int? {
        guard isFavorite else { return nil }
        if let currentOrder { return currentOrder }
        defer { nextFavoriteOrder += 1 }
        return nextFavoriteOrder
    }
}
