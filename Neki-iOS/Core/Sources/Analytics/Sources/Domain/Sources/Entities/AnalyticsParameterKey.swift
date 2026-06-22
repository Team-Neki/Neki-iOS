//
//  AnalyticsParameterKey.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation

public enum AnalyticsParameterKey: String {
    // 공통
    case userId = "user_id"
    case platform = "platform"
    case appVersion = "app_version"
    case notificationType = "notification_type"
    case notificationTone = "notification_tone"
    
    // 아카이빙
    case method = "method"
    case count = "count"
    case albumCount = "album_count"
    case photoCount = "photo_count"
    
    // 지도
    case hasFilter = "has_filter"
    case regionChanged = "region_changed"
    case action = "action"
    case selectedCount = "selected_count"
    case brandName = "brand_name"
    case boothName = "booth_name"
    case favoriteBoothCount = "favorite_booth_count"
    case pinnedBrandCount = "pinned_brand_count"
    case totalBrandCount = "total_brand_count"
    case entryPoint = "entry_point"
    case mapType = "map_type"
    
    // 포즈
    case totalSwipeCount = "total_swipe_count"
    case peopleCount = "people_count"
    
    var name: String { self.rawValue }
}
