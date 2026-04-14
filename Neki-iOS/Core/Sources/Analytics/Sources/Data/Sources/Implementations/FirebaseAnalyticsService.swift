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
        
        #if DEBUG
        Logger.data.log("[Firebase Service] Event: \(name) | Parameters: \(parameters ?? [:])")
        #endif
    }
    
    public func setUserID(_ userID: String?) {
        Analytics.setUserID(userID)
        
        #if DEBUG
        Logger.data.log("[Firebase Service] UserID set: \(userID ?? "nil")")
        #endif
    }
}
