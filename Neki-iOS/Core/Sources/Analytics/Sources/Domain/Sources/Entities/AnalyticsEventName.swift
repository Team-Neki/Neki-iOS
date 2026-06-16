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
    case pushNotificationClick = "push_notification_click"
    
    // 아카이빙
    case archivingView = "archiving_view"
    case photoUpload = "photo_upload"
    case albumCreate = "album_create"
    case albumAddFromDetail = "album_add_from_detail"
    case albumAddFromMulti = "album_add_from_multi"
    case photoAddToAlbum = "photo_add_to_album"
    case photoMove = "photo_move"
    case photoCopy = "photo_copy"
    case photoDetailView = "photo_detail_view"
    case photoMemoCreate = "photo_memo_create"
    
    // 지도
    case mapView = "map_view"
    case mapReSearch = "map_re_search"
    case mapBrandFilterToggle = "map_brand_filter_toggle"
    case boothSelect = "booth_select"
    case boothFavorite = "booth_favorite"
    case mapRouteClick = "map_route_click"
    
    // 포즈
    case poseView = "pose_view"
    case poseRandomStart = "pose_random_start"
    case poseRandomSessionEnd = "pose_random_session_end"
    case poseFilterToggle = "pose_filter_toggle"
    case poseBookmarkFilter = "pose_bookmark_filter"
    case poseBookmark = "pose_bookmark"
    
    // 마이페이지
    case logout = "mypage_logout"
    case withdraw = "mypage_withdraw"
    
    var value: String { self.rawValue }
}
