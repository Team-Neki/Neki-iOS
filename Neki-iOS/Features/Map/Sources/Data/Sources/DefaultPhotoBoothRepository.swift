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
    
    @Dependency(\.networkProvider) private var networkProvider
    
    private var cache: [MapTile: [PhotoBooth]] = [:]
    private var brandMap: [BrandID: PhotoBoothBrand]?
    private var brandFetchTask: Task<[BrandID: PhotoBoothBrand], Error>?
    
    public init() {}
    
    private func ensureBrandsLoaded() async throws -> [BrandID: PhotoBoothBrand] {
        if let existingMap = brandMap { return existingMap }
        
        if let existingTask = brandFetchTask { return try await existingTask.value }
        
        let task = Task<[BrandID: PhotoBoothBrand], Error> {
            let endpoint = MapEndpoint.fetchBrands
            let responseDTO: BaseResponseDTO<FetchPhotoBrandsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            return responseDTO.data?.reduce(into: [:]) { $0[$1.brandName] = $1.toEntity() } ?? [:]
        }
        
        brandFetchTask = task
        
        do {
            let map = try await task.value
            brandMap = map
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
                                    return PhotoBooth(id: dto.id, brand: brand, name: dto.branchName, coordinate: .init(latitude: dto.latitude, longitude: dto.longitude), address: dto.address, nearbyDistance: dto.nearbyDistance)
                                } ?? []
                                
                                return (tile, photoBooths)
                            }
                        }
                        
                        for try await (tile, booths) in group {
                            self.cache[tile] = booths
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
            return PhotoBooth(id: dto.id, brand: brand, name: dto.branchName, coordinate: .init(latitude: dto.latitude, longitude: dto.longitude), address: dto.address, nearbyDistance: dto.nearbyDistance)
        } ?? []
        return photoBooths
    }
}
