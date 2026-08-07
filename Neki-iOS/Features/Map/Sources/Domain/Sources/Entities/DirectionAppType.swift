//
//  DirectionAppType.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/11/26.
//

import Foundation
import DeveloperToolsSupport

/// 길찾기 기능으로 제공되는 외부 앱
public enum DirectionAppType: String, CaseIterable, Sendable {
    case googleMap = "google_map"
    case naverMap = "naver_map"
    case kakaoMap = "kakao_map"
    
    var imageResources: ImageResource {
        switch self {
        case .googleMap: return .imgGooglemapDirection
        case .naverMap: return .imgNavermapDirection
        case .kakaoMap: return .imgKakaomapDirection
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


// MARK: - DirectionAppType + UniversalLink

public extension DirectionAppType {
    func connectLink(coordinate: GeographicCoordinate, name: String) -> URL? {
        let nameEncoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch self {
        case .googleMap:
            // 구글: api=1 & destination=위도,경도
            return URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)")
            
        case .naverMap:
            // 네이버: 모바일 웹 길찾기 페이지 포맷 (도착지 설정)
            // slng, slat(출발지)는 생략 시 현재위치, elng, elat(도착지), etext(도착지명)
            return URL(string: "https://app.map.naver.com/launchApp?cmd=outlink&req=route&dlat=\(coordinate.latitude)&dlng=\(coordinate.longitude)&dname=\(nameEncoded)")
            
        case .kakaoMap:
            // 카카오: 웹/앱 연동형 링크
            // map.kakao.com/link/to/이름,위도,경도
            return URL(string: "https://map.kakao.com/link/to/\(nameEncoded),\(coordinate.latitude),\(coordinate.longitude)")
        }
    }
}
