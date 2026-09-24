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
    /// - Returns: 조회 영역을 포함하는 포토부스 배열 스트림. 조회 실패는 스트림을 순회할 때 전달됩니다.
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

    /// 검색어에 대응하는 특정 종류의 검색 후보 페이지를 가져옵니다.
    /// - Parameters:
    ///   - keyword: 사용자가 입력한 검색어 원문
    ///   - type: 조회할 후보의 종류
    ///   - page: 0부터 시작하는 페이지 번호
    ///   - size: 한 페이지에 담을 후보 수
    /// - Returns: 서버 순서를 유지한 후보 페이지
    func searchCandidates(
        keyword: String,
        type: PhotoBoothSearchCandidateType,
        page: Int,
        size: Int
    ) async throws -> PhotoBoothSearchCandidatePage

    /// 고른 지역·역에 속한 포토부스 목록을 가져옵니다.
    ///
    /// 시군구를 고르면 그 아래 읍면동까지 포함하며, 역 주변 반경은 수집 단계에서 미리 계산된
    /// 값이라 클라이언트가 조정할 수 없습니다.
    /// - Parameters:
    ///   - target: 사용자가 고른 지역 또는 지하철역
    ///   - userCoordinate: 거리 계산의 기준이 되는 사용자 현재 위치. `nil`이면 거리가 내려오지 않습니다.
    /// - Returns: 기준 위치가 있으면 가까운 순, 없으면 브랜드와 지점 이름 순으로 정렬된 포토부스 배열
    func readSearchResultPhotoBooths(
        target: PhotoBoothSearchTarget,
        userCoordinate: GeographicCoordinate?
    ) async throws -> [PhotoBooth]

    /// 고른 지역·역의 부스 목록에서 실제로 쓸 수 있는 브랜드 필터를 가져옵니다.
    ///
    /// 그 범위에 없는 브랜드를 눌러 빈 화면을 보는 일이 없도록, 목록에 있는 브랜드만 내려옵니다.
    /// - Parameter target: 사용자가 고른 지역 또는 지하철역
    /// - Returns: 사용자별 브랜드 정렬 순서를 유지한 브랜드 필터 배열
    func readSearchResultBrandFilters(
        target: PhotoBoothSearchTarget
    ) async throws -> [PhotoBoothSearchBrandFilter]
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
