//
//  PhotoBoothListPreviewData.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/10/26.
//

import UIKit
import ComposableArchitecture

/// 목록 시트, 브랜드 필터 시트, 브랜드 칩의 `#Preview`가 함께 쓰는 목업 데이터입니다.
///
/// 브랜드 로고는 번들 이미지를 임시 폴더에 PNG로 내려 `file://` URL로 넘기므로 미리보기에서도 실제 로고가 보입니다.
enum PhotoBoothListPreviewData {
    static let brands: [PhotoBoothBrand] = [
        brand(id: 1, name: "인생네컷", englishName: "life4cut", logo: ImageResource.imgLife4CutOriginal),
        brand(id: 2, name: "하루필름", englishName: "harufilm", logo: ImageResource.imgHarufilmOriginal),
        brand(id: 3, name: "포토이즘", englishName: "photoism", logo: ImageResource.imgPhotoismOriginal),
        brand(id: 4, name: "포토그레이", englishName: "photogray", logo: ImageResource.imgPhotograyOriginal),
        brand(id: 5, name: "포토시그니처", englishName: "photosignature", logo: ImageResource.imgPhotosignatureOriginal),
        brand(id: 6, name: "플랜비스튜디오", englishName: "planbstudio", logo: ImageResource.imgPlanbstudioOriginal),
        brand(id: 7, name: "모노맨션", englishName: "monomansion", logo: nil),
        brand(id: 8, name: "돈룩업", englishName: "dontlookup", logo: nil),
        brand(id: 9, name: "포토랩플러스", englishName: "photolabplus", logo: nil),
        brand(id: 10, name: "픽닷", englishName: "picdot", logo: nil),
        brand(id: 11, name: "비룸스튜디오", englishName: "broomstudio", logo: nil)
    ]

    /// 사당역 주변을 검색한 것처럼 보이는 부스 5곳입니다.
    static let searchResultBooths: [PhotoBooth] = brands.prefix(5).enumerated().map { index, brand in
        PhotoBooth(
            id: index + 1,
            brand: brand,
            name: "사당역점",
            coordinate: GeographicCoordinate(latitude: 37.4765, longitude: 126.9816),
            address: "서울특별시 동작구 사당동",
            nearbyDistance: 300 + index * 140,
            isFavorite: index == 1
        )
    }

    /// 검색 결과를 보는 중인 목록 상태입니다. `selectedBrands`를 주면 그 브랜드의 부스만 목록에 남깁니다.
    static func searchResultState(selecting selectedBrands: Set<PhotoBoothBrand> = []) -> PhotoBoothListFeature.State {
        var state = PhotoBoothListFeature.State()
        state.brands = IdentifiedArray(uniqueElements: brands)
        state.isSearchResultPresented = true
        state.searchResultBrandFilters = brands.map { PhotoBoothSearchBrandFilter(brand: $0, count: 1) }
        state.filteredBrands = selectedBrands
        state.visibleBooths = IdentifiedArray(
            uniqueElements: searchResultBooths.filter { selectedBrands.isEmpty || selectedBrands.contains($0.brand) }
        )
        return state
    }

    /// 지도 영역을 조회 중인 기본 목록 상태입니다.
    static func nearbyState() -> PhotoBoothListFeature.State {
        var state = PhotoBoothListFeature.State()
        state.brands = IdentifiedArray(uniqueElements: brands)
        state.visibleBooths = IdentifiedArray(uniqueElements: searchResultBooths)
        return state
    }

    /// 미리보기에서 칩을 눌러도 애널리틱스가 실제로 나가지 않도록 로그를 비운 스토어입니다.
    @MainActor
    static func store(_ state: PhotoBoothListFeature.State) -> StoreOf<PhotoBoothListFeature> {
        Store(initialState: state) {
            PhotoBoothListFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { _ in }
        }
    }
}


// MARK: - PhotoBoothListPreviewData + Helper

private extension PhotoBoothListPreviewData {
    static func brand(id: Int, name: String, englishName: String, logo: ImageResource?) -> PhotoBoothBrand {
        PhotoBoothBrand(
            id: id,
            name: name,
            englishName: englishName,
            imageURL: logo.flatMap { logoFileURL($0, name: englishName) }
        )
    }

    /// 에셋 카탈로그 이미지는 URL로 가리킬 수 없어, 임시 폴더에 PNG로 한 번 내려 두고 그 파일 URL을 씁니다.
    static func logoFileURL(_ resource: ImageResource, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-brand-\(name).png")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        guard let data = UIImage(resource: resource).pngData() else { return nil }
        try? data.write(to: url)
        return url
    }
}
