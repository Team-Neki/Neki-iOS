//
//  PhotoBoothCacheMetadata.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/11/26.
//

import Foundation

/// 캐시 데이터 생성 싲머과 선택적인 서버 검증 정보를 나타냅니다.
///
/// 캐시 신선도 정책은 `cachedAt`을 기준으로 만료 여부를 판단하며,
/// `validationToken`은 특정 검증 방식에 결합하지 않고 추후 서버 재검증에 활용할 수 있도록 확장가능성만 남겨놨습니다. (예: E-Tag 방식으로 확장 등)
struct PhotoBoothCacheMetadata: Sendable {
    let cachedAt: Date
    let validationToken: String?
}
