//
//  PhotoBoothTimeToLivePolicy.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/11/26.
//

import Foundation

/// 캐시 생성 시점으로부터 지정된 수명 동안만 데이터를 유효한 것으로 판단하는 캐시 정책입니다.
///
/// 경과 시간이 `lifetime`과 같아지는 시점부터 해당 데이터는 만료된 것으로 간주해 처리합니다.
struct PhotoBoothTimeToLivePolicy: PhotoBoothCacheFreshnessPolicy {
    let lifetime: TimeInterval

    func isFresh(metadata: PhotoBoothCacheMetadata, now: Date) -> Bool {
        now.timeIntervalSince(metadata.cachedAt) < lifetime
    }
}
