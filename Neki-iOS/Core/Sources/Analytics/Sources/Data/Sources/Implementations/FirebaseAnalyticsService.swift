//
//  FirebaseAnalyticsService.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/14/26.
//

import Foundation
import FirebaseAnalytics
import os

public final actor FirebaseAnalyticsService: AnalyticsService {
    public init() {}
    
    public func sendEvent(name: String, parameters: [String : Any]?) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    public func setUserID(_ userID: String?) {
        Analytics.setUserID(userID)
    }
}
