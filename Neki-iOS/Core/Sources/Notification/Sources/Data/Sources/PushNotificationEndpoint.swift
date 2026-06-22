//
//  PushNotificationEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation
import os

enum PushNotificationEndpoint {
    case setDeviceToken(dto: FCMDeviceTokenDTO.Request)
    case fetchRecentNotifications
}


// MARK: - PushNotificationEndpoint + Endpoint

extension PushNotificationEndpoint: Endpoint {
    var authorizationType: AuthorizationType {
        switch self {
        case .setDeviceToken, .fetchRecentNotifications: return .bearer
        }
    }
    
    var contentType: HTTPContentType { .json }
    
    var path: String {
        switch self {
        case .setDeviceToken: "notifications"
        case .fetchRecentNotifications: "notifications/recent"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .setDeviceToken: return .patch
        case .fetchRecentNotifications: return .get
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case let .setDeviceToken(dto): return dto
        case .fetchRecentNotifications: return nil
        }
    }
}
