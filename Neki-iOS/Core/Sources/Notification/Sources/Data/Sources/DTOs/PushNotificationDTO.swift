//
//  PushNotificationDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/22/26.
//

import Foundation

struct PushNotificationDTO: Decodable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let link: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, link, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        link = try container.decodeIfPresent(String.self, forKey: .link)

        do {
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        } catch {
            createdAt = nil
        }
    }

    func toEntity() -> PushNotificationListItem {
        PushNotificationListItem(
            id: id,
            type: type,
            title: title,
            body: body,
            sentAt: createdAt,
            link: link
        )
    }
}
