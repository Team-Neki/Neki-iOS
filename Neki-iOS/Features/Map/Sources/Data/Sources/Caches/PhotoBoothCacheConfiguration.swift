//
//  PhotoBoothCacheConfiguration.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/11/26.
//

/// 포토부스 타일 캐시의 용량 제한과 신선도 정책을 구성합니다.
///
/// - Note: 캐시의 제한값은 메모리 사용과 제거 시점을 조절하기 위한 기준이며,
/// 실제 보관 개수나 객체 제거 순서는 고려하지 않았습니다.
struct PhotoBoothCacheConfiguration: Sendable {
    let maximumTileCount: Int
    let maximumPhotoBoothCount: Int
    let freshnessPolicy: any PhotoBoothCacheFreshnessPolicy

    static let standard = PhotoBoothCacheConfiguration(
        maximumTileCount: 128,
        maximumPhotoBoothCount: 5_000,
        freshnessPolicy: PhotoBoothTimeToLivePolicy(lifetime: 60 * 10)
    )
}
