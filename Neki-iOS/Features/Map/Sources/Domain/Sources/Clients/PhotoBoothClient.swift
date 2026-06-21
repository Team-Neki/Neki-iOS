//
//  PhotoBoothClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/31/25.
//

import Foundation
import ComposableArchitecture

@DependencyClient
public struct PhotoBoothClient {
    /// 지도 영역(bounds) 내의 포토부스 데이터를 가져옵니다.
    public var fetchPhotoBooths: @Sendable (_ bounds: GeographicBoundingBox) async throws -> AsyncStream<[PhotoBooth]>
    /// 중심 좌표 주변 거리순으로 포토부스 데이터를 가져옵니다.
    public var fetchNearbyPhotoBooths: @Sendable (_ coordinate: GeographicCoordinate) async throws -> [PhotoBooth]
    /// 특정 포토부스의 즐겨찾기 상태를 변경합니다.
    public var updatePhotoBoothFavorite: @Sendable (_ id: Int, _ isFavorite: Bool) async throws -> Void
    /// 즐겨찾기 포토부스 목록 조회
    public var fetchFavoritePhotoBooths: @Sendable () async throws -> [PhotoBooth]
    /// 지원 브랜드 정보 조회
    public var loadBrands: @Sendable () async throws -> [PhotoBoothBrand]
    /// 브랜드 필터칩 노출 순서 변경
    public var updateBrandOrder: @Sendable (_ brands: [PhotoBoothBrand]) async throws -> [PhotoBoothBrand]
}


// MARK: - PhotoBoothClient + DependencyKey

extension PhotoBoothClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.photoBoothRepository) var photoBoothRepository
        
        return PhotoBoothClient { bounds in
            await photoBoothRepository.readPhotoBooths(in: bounds)
        } fetchNearbyPhotoBooths: { coordinate in
            try await photoBoothRepository.readNearbyPhotoBooths(coordinate: coordinate)
        } updatePhotoBoothFavorite: { id, isFavorite in
            try await photoBoothRepository.updatePhotoBoothFavorite(id: id, isFavorite: isFavorite)
        } fetchFavoritePhotoBooths: {
            try await photoBoothRepository.readFavoritePhotoBooths()
        } loadBrands: {
            try await photoBoothRepository.loadBrands()
        } updateBrandOrder: { brands in
            try await photoBoothRepository.updateBrandOrder(brands)
        }
    }()
}


// MARK: - PhotoBoothClient + Dependency Accessor

public extension DependencyValues {
    var photoBoothClient: PhotoBoothClient {
        get { self[PhotoBoothClient.self] }
        set { self[PhotoBoothClient.self] = newValue }
    }
}
