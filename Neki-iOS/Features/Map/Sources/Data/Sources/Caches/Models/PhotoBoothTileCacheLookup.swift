//
//  PhotoBoothTileCacheLookup.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/11/26.
//

/// 타일 캐시 조회 결과를 데이터 존재 여부와 신선도에 따라 구분합니다.
///
/// 만료된 스냅샷도 폐기하지 않고 반환하여 최신 데이터 요청에 실패했을 때 fallback으로 활용할 수 있습니다.
enum PhotoBoothTileCacheLookup: Sendable {
    case fresh(PhotoBoothTileCacheSnapshot)
    
    /// 만료되었긴 하지만 네트워크 갱신 실패 시 fallback으로 활용할 수 있습니다.
    case stale(PhotoBoothTileCacheSnapshot)
    
    case missing
}
