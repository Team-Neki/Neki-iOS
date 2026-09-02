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
    /// - Throws: 캐시와 네트워크 모두에서 유효한 타일을 확보하지 못한 경우의 조회 오류
    func readPhotoBooths(in bounds: GeographicBoundingBox) async -> AsyncThrowingStream<[PhotoBooth], Error>

    /// 특정 포토부스의 즐겨찾기 상태를 변경합니다.
    /// - Parameters:
    ///   - id: 포토부스 지점 식별자
    ///   - isFavorite: 변경할 즐겨찾기 상태
    func updatePhotoBoothFavorite(id: Int, isFavorite: Bool) async throws

    /// 서버 기준으로 즐겨찾기한 포토부스 목록을 가져옵니다.
    /// - Returns: 서버에서 내려준 순서의 즐겨찾기 포토부스 배열
    func readFavoritePhotoBooths() async throws -> [PhotoBooth]

    /// 브랜드들의 정보를 가져옵니다.
    /// - Returns: 우선순위로 정렬된 브랜드 배열
    func loadBrands() async throws -> [PhotoBoothBrand]

    /// 브랜드 필터칩 노출 순서를 변경합니다.
    /// - Parameter brands: 사용자가 저장한 브랜드 순서
    /// - Returns: 저장된 순서가 반영된 브랜드 배열
    func updateBrandOrder(_ brands: [PhotoBoothBrand]) async throws -> [PhotoBoothBrand]
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
