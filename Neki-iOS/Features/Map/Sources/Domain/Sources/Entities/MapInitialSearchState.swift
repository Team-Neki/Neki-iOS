//
//  MapInitialSearchState.swift
//  Neki-iOS
//
//  Created by SwainYun on 5/6/26.
//

import Foundation

/// 지도 진입 직후 첫 POI 검색이 가능한지 표현하는 상태
public enum MapInitialSearchState: Sendable, Equatable {
    case awaitingPermission
    case waitingForUserLocation
    case readyForDefaultLocation
    case readyForUserLocation
    case completed
}
