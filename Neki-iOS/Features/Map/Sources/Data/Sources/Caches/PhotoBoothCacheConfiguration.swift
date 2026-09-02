//
//  PhotoBoothCacheConfiguration.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/11/26.
//

/// 포토부스 조회 결과와 브랜드 데이터 캐시의 용량 제한 및 신선도 정책을 구성합니다.
///
/// - Note: `NSCache`의 제한값은 메모리 사용과 제거 시점을 조절하기 위한 기준이며,
/// 실제 보관 개수나 객체 제거 순서를 보장하지 않습니다.
struct PhotoBoothCacheConfiguration: Sendable {
    let maximumRegionCount: Int
    let maximumPhotoBoothCount: Int
    let freshnessPolicy: any PhotoBoothCacheFreshnessPolicy

    static let standard = PhotoBoothCacheConfiguration(
        maximumRegionCount: 128,
        maximumPhotoBoothCount: 5_000,
        freshnessPolicy: PhotoBoothTimeToLivePolicy(lifetime: 60 * 10)
    )
}
