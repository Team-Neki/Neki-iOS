//
//  AppRouteLinkBuilder.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation

protocol AppRouteLinkBuilding: Sendable {
    func makeLink(for route: AppRouteRequest) throws -> URL
}

struct AppRouteLinkBuilder: AppRouteLinkBuilding {
    private let scheme: String
    private let allowedSchemes: Set<String> = ["neki", "neki-dev"]

    init(scheme: String = "neki") {
        self.scheme = scheme.lowercased()
    }

    func makeLink(for route: AppRouteRequest) throws -> URL {
        guard allowedSchemes.contains(scheme) else {
            throw AppRouteLinkError.unsupportedScheme
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

        case .notificationList:
            components.host = "notification"

        case let .shareExtension(appGroupID):
            components.host = "shareExtension"
            components.queryItems = [
                URLQueryItem(name: "appGroupID", value: appGroupID)
            ]
        }

        guard let url = components.url else {
            throw AppRouteLinkError.invalidURL
        }
        return url
    }

    private func resourcePath(
        type: String,
        id: AppRouteRequest.ResourceID
    ) throws -> String {
        guard id > 0 else {
            throw AppRouteLinkError.invalidResourceID
        }
        return "/\(type)/\(id)"
    }
}
