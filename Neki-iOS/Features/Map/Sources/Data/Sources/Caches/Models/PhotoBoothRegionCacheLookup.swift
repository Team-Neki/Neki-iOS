//
//  PhotoBoothRegionCacheLookup.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/30/26.
//

/// 지역 캐시 조회 결과를 데이터 존재 여부와 신선도에 따라 구분합니다.
enum PhotoBoothRegionCacheLookup: Sendable {
    case fresh(PhotoBoothRegionCacheSnapshot)

    /// 만료되었지만 네트워크 갱신 실패 시 fallback으로 활용할 수 있습니다.
    case stale(PhotoBoothRegionCacheSnapshot)

    case missing
}
