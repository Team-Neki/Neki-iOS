//
//  AnalyticsService.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation

public protocol AnalyticsService: Sendable {
    func sendEvent(name: String, parameters: [String: Any]?) async
    func setUserID(_ userID: String?) async
}
