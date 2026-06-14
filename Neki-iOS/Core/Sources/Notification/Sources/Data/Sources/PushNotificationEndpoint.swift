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
}


// MARK: - PushNotificationEndpoint + Endpoint

extension PushNotificationEndpoint: Endpoint {
    var authorizationType: AuthorizationType {
        switch self {
        case .setDeviceToken: return .bearer
        }
    }
    
    var contentType: HTTPContentType { .json }
    
    var path: String {
        switch self {
        case .setDeviceToken: "notifications"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .setDeviceToken: return .patch
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case let .setDeviceToken(dto): return dto
        }
    }
}
