//
//  AppStorageKey.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/2/26.
//

import Foundation

public struct AppStorageKey {
    public static let userSessionStatus: String = "UserSessionStatus"

    public static func marketingConsentAlertPresentationCount(userID: Int) -> String {
        "MarketingConsentAlertPresentationCount_\(userID)"
    }

    public static func marketingConsentLastManagedAt(userID: Int) -> String {
        "MarketingConsentLastManagedAt_\(userID)"
    }

    public static func marketingConsentManagementStatus(userID: Int) -> String {
        "MarketingConsentManagementStatus_\(userID)"
    }

}

public enum MarketingConsentManagementStatus: String {
    case unconfirmed
    case approved
    case rejected
}
