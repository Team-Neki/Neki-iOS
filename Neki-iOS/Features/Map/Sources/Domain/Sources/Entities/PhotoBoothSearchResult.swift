//
//  PhotoBoothSearchResult.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/4/26.
//

import Foundation

/// 고른 검색 후보로 지도를 다시 그릴 때 필요한 값입니다.
///
/// 부스 목록과 필터 칩은 요청 body가 같아 항상 함께 조회하므로 한 묶음으로 다룹니다.
public struct PhotoBoothSearchResult: Equatable, Sendable {
    /// 지도에 그릴 부스 목록입니다.
    public let photoBooths: [PhotoBooth]
    /// 그 목록에서 쓸 수 있는 브랜드 필터입니다. 부스를 직접 고른 경우에는 비어 있습니다.
    public let brandFilters: [PhotoBoothSearchBrandFilter]

    public init(photoBooths: [PhotoBooth], brandFilters: [PhotoBoothSearchBrandFilter]) {
        self.photoBooths = photoBooths
        self.brandFilters = brandFilters
    }
}

/// 고른 지역·역의 목록에서 쓸 수 있는 브랜드 필터 한 건입니다.
///
/// 그 범위에 없는 브랜드를 눌러 빈 화면을 보는 일이 없도록, 목록에 실제로 있는 브랜드만 담습니다.
public struct PhotoBoothSearchBrandFilter: Identifiable, Equatable, Sendable {
    public let brand: PhotoBoothBrand
    /// 그 범위 안에 있는 해당 브랜드의 부스 개수입니다.
    public let count: Int

    public var id: PhotoBoothBrand.ID { brand.id }

    public init(brand: PhotoBoothBrand, count: Int) {
        self.brand = brand
        self.count = count
    }
}
