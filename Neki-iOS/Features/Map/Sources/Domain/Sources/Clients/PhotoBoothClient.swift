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
    public var fetchPhotoBooths: @Sendable (_ bounds: GeographicBoundingBox) async throws -> AsyncThrowingStream<[PhotoBooth], Error>
    /// 특정 포토부스의 즐겨찾기 상태를 변경합니다.
    public var updatePhotoBoothFavorite: @Sendable (_ id: Int, _ isFavorite: Bool) async throws -> Void
    /// 즐겨찾기 포토부스 목록 조회
    public var fetchFavoritePhotoBooths: @Sendable () async throws -> [PhotoBooth]
    /// 지원 브랜드 정보 조회
    public var loadBrands: @Sendable () async throws -> [PhotoBoothBrand]
    /// 브랜드 필터칩 노출 순서 변경
    public var updateBrandOrder: @Sendable (_ brands: [PhotoBoothBrand]) async throws -> [PhotoBoothBrand]
    /// 검색어와 페이지 번호에 대응하는 검색 후보 조회
    ///
    /// - Note: 페이지 번호 방식의 가계약이며 Mock API 확정 후 요청 규격을 조정합니다.
    public var fetchSearchCandidates: @Sendable (_ query: PhotoBoothSearchQuery, _ page: Int) async throws -> PhotoBoothSearchCandidatePage
    /// 사용자가 선택한 후보와 페이지 번호에 대응하는 포토부스 조회
    ///
    /// - Note: 후보 식별자와 페이지 요청 규격은 Mock API 확정 후 보강합니다.
    public var fetchSearchPhotoBooths: @Sendable (_ candidate: PhotoBoothSearchCandidate, _ page: Int) async throws -> PhotoBoothSearchResultPage
}


// MARK: - PhotoBoothClient + DependencyKey

extension PhotoBoothClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.photoBoothRepository) var photoBoothRepository

        var client = PhotoBoothClient()
        client.fetchPhotoBooths = { bounds in
            await photoBoothRepository.readPhotoBooths(in: bounds)
        }
        client.updatePhotoBoothFavorite = { id, isFavorite in
            try await photoBoothRepository.updatePhotoBoothFavorite(id: id, isFavorite: isFavorite)
        }
        client.fetchFavoritePhotoBooths = {
            try await photoBoothRepository.readFavoritePhotoBooths()
        }
        client.loadBrands = {
            try await photoBoothRepository.loadBrands()
        }
        client.updateBrandOrder = { brands in
            try await photoBoothRepository.updateBrandOrder(brands)
        }
        return client
    }()
}


// MARK: - PhotoBoothClient + Dependency Accessor

public extension DependencyValues {
    var photoBoothClient: PhotoBoothClient {
        get { self[PhotoBoothClient.self] }
        set { self[PhotoBoothClient.self] = newValue }
    }
}
