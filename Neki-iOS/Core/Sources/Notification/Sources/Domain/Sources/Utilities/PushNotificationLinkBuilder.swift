//
//  PushNotificationLinkBuilder.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation

public protocol PushNotificationLinkBuilding: Sendable {
    func makeLink(for route: PushNotificationRoute) throws -> URL
}

public struct PushNotificationLinkBuilder: PushNotificationLinkBuilding {
    private let scheme: String
    private let allowedSchemes: Set<String> = ["neki", "neki-dev"]

    public init(scheme: String = "neki") {
        self.scheme = scheme.lowercased()
    }

    public func makeLink(for route: PushNotificationRoute) throws -> URL {
        guard allowedSchemes.contains(scheme) else {
            throw PushNotificationLinkError.unsupportedScheme
        }

        var components = URLComponents()
        components.scheme = scheme

        switch route {
        case .map:
            components.host = "map"

        case let .mapBrand(id):
            components.host = "map"
            components.path = try resourcePath(type: "brand", id: id)

        case let .mapBooth(id):
            components.host = "map"
            components.path = try resourcePath(type: "booth", id: id)

        case .archive:
            components.host = "archive"

        case let .archivePhoto(id):
            components.host = "archive"
            components.path = try resourcePath(type: "photo", id: id)

        case .pose:
            components.host = "pose"

        case .myPage:
            components.host = "mypage"
        }

        guard let url = components.url else {
            throw PushNotificationLinkError.invalidURL
        }
        return url
    }

    private func resourcePath(
        type: String,
        id: PushNotificationRoute.ResourceID
    ) throws -> String {
        guard id > 0 else {
            throw PushNotificationLinkError.invalidResourceID
        }
        return "/\(type)/\(id)"
    }
}
