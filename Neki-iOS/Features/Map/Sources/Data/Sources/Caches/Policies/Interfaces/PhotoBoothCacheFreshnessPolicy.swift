//
//  PhotoBoothCacheFreshnessPolicy.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/11/26.
//

import Foundation

/// 캐시 메타데이터와 현재 시각을 이용해 데이터를 재사용할 수 있는지 확인합니다.
///
/// 만료 판단을 캐시 저장소와 분리하여 TTL 이외의 캐시 정책으로 교체할 수 있도록 하는 취지이며,
/// 현재 시각을 외부에서 전달받아 호출 시점에 일관된 기준으로 여러 캐시를 평가할 수 있도록 합니다.
protocol PhotoBoothCacheFreshnessPolicy: Sendable {
    func isFresh(metadata: PhotoBoothCacheMetadata, now: Date) -> Bool
}
