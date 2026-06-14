//
//  FCMDeviceTokenDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation

enum FCMDeviceTokenDTO {
    struct Request: Encodable {
        let deviceToken: PushNotificationToken
        let isPushNotificationAgreed: Bool
        
        enum CodingKeys: String, CodingKey {
            case deviceToken
            case isPushNotificationAgreed = "pushAgreed"
        }
    }
}
