//
//  AnalyticsEventName.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation

public enum AnalyticsEventName: String {
    // 공통
    case appOpen = "app_open"
    
    // 아카이빙
    case photoUpload = "photo_upload"
    case albumCreate = "album_create"
    case albumAddFromDetail = "album_add_from_detail"
    case albumAddFromMulti = "album_add_from_multi"
    case photoMove = "photo_move"
    case photoCopy = "photo_copy"
    case photoDetailView = "photo_detail_view"
    case photoMemoCreate = "photo_memo_create"
    
    // 지도
    case mapView = "map_view"
    case mapResearch = "map_research"
    case mapBrandFilterToggle = "map_brand_filter_toggle"
    case boothSelect = "booth_select"
    case mapRouteClick = "map_route_click"
    
    // 포즈
    case poseView = "pose_view"
    case poseRandomStart = "pose_random_start"
    case poseRandomSwipeBatch = "pose_random_swipe_batch"
    case poseRandomSessionEnd = "pose_random_session_end"
    
    var value: String { self.rawValue }
}
