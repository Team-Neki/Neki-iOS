//
//  AdvertisingTrackingAuthorizationPhase.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/26/26.
//

/// 광고 추적 권한을 확인하고 요청하는 과정의 진행 상태를 나타냅니다.
public enum AdvertisingTrackingAuthorizationPhase: Equatable, Sendable {
    case idle
    case resolving
    case resolved
}
