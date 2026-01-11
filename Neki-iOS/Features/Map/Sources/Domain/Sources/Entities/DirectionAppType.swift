//
//  DirectionAppType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/11/26.
//

import Foundation
import DeveloperToolsSupport

/// 길찾기 기능으로 제공되는 외부 앱
public enum DirectionAppType: CaseIterable {
    case googleMap, naverMap, kakaoMap
    
    var imageResources: ImageResource {
        switch self {
        case .googleMap: return .imgGooglemapModal
        case .naverMap: return .imgNavermapModal
        case .kakaoMap: return .imgKakaomapModal
        }
    }
    
    var displayName: String {
        switch self {
        case .googleMap: return "구글맵"
        case .naverMap: return "네이버 지도"
        case .kakaoMap: return "카카오 맵"
        }
    }
}
