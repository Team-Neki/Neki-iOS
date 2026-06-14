//
//  PushNotificationLinkParser.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation

public protocol PushNotificationLinkParsing: Sendable {
    func parse(_ url: URL) throws -> PushNotificationRoute
}

public struct PushNotificationLinkParser: PushNotificationLinkParsing {
    private let allowedSchemes: Set<String>

    public init(allowedSchemes: Set<String> = ["neki", "neki-dev"]) {
        self.allowedSchemes = allowedSchemes
    }

    public func parse(_ url: URL) throws -> PushNotificationRoute {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              allowedSchemes.contains(scheme)
        else {
            throw PushNotificationLinkError.unsupportedScheme
        }

        guard components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              let host = components.host?.lowercased()
        else {
            throw PushNotificationLinkError.unsupportedRoute
        }

        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)

        switch host {
        case "map":
            if pathComponents.isEmpty {
                return .map
            }
            guard pathComponents.count == 2 else {
                throw PushNotificationLinkError.unsupportedRoute
            }
            switch pathComponents[0] {
            case "brand":
                return .mapBrand(try resourceID(from: pathComponents[1]))
            case "booth":
                return .mapBooth(try resourceID(from: pathComponents[1]))
            default:
                throw PushNotificationLinkError.unsupportedRoute
            }

        case "archive":
            if pathComponents.isEmpty {
                return .archive
            }
            guard pathComponents.count == 2, pathComponents[0] == "photo" else {
                throw PushNotificationLinkError.unsupportedRoute
            }
            return .archivePhoto(try resourceID(from: pathComponents[1]))

        case "pose":
            guard pathComponents.isEmpty else {
                throw PushNotificationLinkError.unsupportedRoute
            }
            return .pose

        case "mypage":
            guard pathComponents.isEmpty else {
                throw PushNotificationLinkError.unsupportedRoute
            }
            return .myPage

        default:
            throw PushNotificationLinkError.unsupportedRoute
        }
    }

    private func resourceID(
        from rawValue: String
    ) throws -> PushNotificationRoute.ResourceID {
        guard let id = Int(rawValue), id > 0 else {
            throw PushNotificationLinkError.invalidResourceID
        }
        return id
    }
}
