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
    /// 검색어에 대응하는 특정 종류의 검색 후보 페이지 조회
    public var searchCandidates: @Sendable (_ query: PhotoBoothSearchQuery, _ type: PhotoBoothSearchCandidateType, _ page: Int) async throws -> PhotoBoothSearchCandidatePage
    /// 사용자가 선택한 검색 후보에 대응하는 포토부스 조회
    ///
    /// 포토부스 후보는 검색 응답에 지도에 필요한 값이 모두 들어 있어 네트워크 호출 없이 자기 자신을 반환합니다.
    /// `userCoordinate`는 응답에 담길 거리의 기준이며, 위치를 알 수 없으면 `nil`을 전달해 거리를 받지 않습니다.
    public var fetchSearchPhotoBooths: @Sendable (_ candidate: PhotoBoothSearchCandidate, _ userCoordinate: GeographicCoordinate?) async throws -> [PhotoBooth]
    /// 사용자가 선택한 검색 후보의 부스 목록에서 쓸 수 있는 브랜드 필터 조회
    ///
    /// 부스 목록과 요청 body가 같아 항상 함께 호출합니다.
    /// 포토부스 후보는 지도에 한 지점만 찍어 필터가 필요 없으므로 네트워크 호출 없이 빈 배열을 반환합니다.
    public var fetchSearchBrandFilters: @Sendable (_ candidate: PhotoBoothSearchCandidate) async throws -> [PhotoBoothSearchBrandFilter]
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
        client.searchCandidates = { query, type, page in
            try await photoBoothRepository.searchCandidates(
                keyword: query.rawValue,
                type: type,
                page: page,
                size: PhotoBoothSearchPaging.size
            )
        }
        client.fetchSearchPhotoBooths = { candidate, userCoordinate in
            switch candidate {
            case let .region(region):
                return try await photoBoothRepository.readSearchResultPhotoBooths(
                    target: .region(code: region.code),
                    userCoordinate: userCoordinate
                )

            case let .subwayStation(station):
                return try await photoBoothRepository.readSearchResultPhotoBooths(
                    target: .subwayStation(name: station.name, lineName: station.lineName),
                    userCoordinate: userCoordinate
                )

            case let .photoBooth(photoBooth):
                return [photoBooth]
            }
        }
        client.fetchSearchBrandFilters = { candidate in
            switch candidate {
            case let .region(region):
                return try await photoBoothRepository.readSearchResultBrandFilters(
                    target: .region(code: region.code)
                )

            case let .subwayStation(station):
                return try await photoBoothRepository.readSearchResultBrandFilters(
                    target: .subwayStation(name: station.name, lineName: station.lineName)
                )

            case .photoBooth:
                return []
            }
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
