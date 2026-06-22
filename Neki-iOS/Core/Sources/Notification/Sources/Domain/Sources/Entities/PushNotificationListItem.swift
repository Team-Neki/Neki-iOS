//
//  PushNotificationListItem.swift
//  Neki-iOS
//
//  Created by Codex on 6/19/26.
//

import Foundation

public struct PushNotificationListItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let type: String
    public let title: String
    public let body: String
    public let receivedAt: Date?
    public let link: String?
    public let isRead: Bool

    public init(
        id: Int,
        type: String,
        title: String,
        body: String,
        receivedAt: Date? = nil,
        link: String? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.receivedAt = receivedAt
        self.link = link
        self.isRead = isRead
    }
}
