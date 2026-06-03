//
//  PhotoBoothRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation
import Dependencies

protocol PhotoBoothRepository {
    /// 특정 지도 영역 내의 포토부스 목록을 가져옵니다.
    /// - Parameter bounds: 조회 시점의 지리적 영역
    /// - Returns: 해당 영역 내의 포토부스 배열 스트림
    func readPhotoBooths(in bounds: GeographicBoundingBox) async -> AsyncStream<[PhotoBooth]>

    /// 기준 좌표에서 거리순으로 포토부스 목록을 가져옵니다.
    /// - Parameter coordinate: 기준 좌표
    /// - Returns: 거리순으로 정렬된 포토부스 배열
    func readNearbyPhotoBooths(coordinate: GeographicCoordinate) async throws -> [PhotoBooth]

    /// 특정 포토부스의 즐겨찾기 상태를 변경합니다.
    /// - Parameters:
    ///   - id: 포토부스 지점 식별자
    ///   - isFavorite: 변경할 즐겨찾기 상태
    func updatePhotoBoothFavorite(id: Int, isFavorite: Bool) async throws

    /// 레포지토리 캐시 기준으로 즐겨찾기한 포토부스 목록을 가져옵니다.
    /// - Returns: 즐겨찾기한 순서대로 정렬된 포토부스 배열
    func readFavoritePhotoBooths() async -> [PhotoBooth]

    /// 브랜드들의 정보를 가져옵니다.
    /// - Returns: 우선순위로 정렬된 브랜드 배열
    func loadBrands() async throws -> [PhotoBoothBrand]
}

private enum PhotoBoothRepositoryKey: DependencyKey {
    static let liveValue: PhotoBoothRepository = {
        DefaultPhotoBoothRepository()
    }()
}

extension DependencyValues {
    var photoBoothRepository: PhotoBoothRepository {
        get { self[PhotoBoothRepositoryKey.self] }
        set {self[PhotoBoothRepositoryKey.self] = newValue }
    }
}
