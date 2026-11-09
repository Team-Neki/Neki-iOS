//
//  AppStorageKey.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/2/26.
//

import Foundation

public struct AppStorageKey {
    public static let userSessionStatus: String = "UserSessionStatus"
    public static let recentLoginProvider: String = "RecentLoginProvider"

    public static func notificationGuideRecord(userID: Int) -> String {
        "NotificationGuideRecord_\(userID)"
    }

}
