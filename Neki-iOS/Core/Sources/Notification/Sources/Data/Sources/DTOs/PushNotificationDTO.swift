//
//  PushNotificationDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/22/26.
//

import Foundation

struct PushNotificationDTO: Codable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let link: String?
    let createdAt: String

    func toEntity() -> PushNotificationListItem {
        PushNotificationListItem(
            id: id,
            type: type,
            title: title,
            body: body,
            receivedAt: createdAt.toISO8601DateOrNil(),
            link: link
        )
    }
}
