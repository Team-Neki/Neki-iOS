//
//  AppRouteLinkParser.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation

protocol AppRouteLinkParsing: Sendable {
    func parse(_ url: URL) throws -> AppRouteRequest
}

struct AppRouteLinkParser: AppRouteLinkParsing {
    private let allowedSchemes: Set<String>

    init(allowedSchemes: Set<String> = ["neki", "neki-dev"]) {
        self.allowedSchemes = allowedSchemes
    }

    func parse(_ url: URL) throws -> AppRouteRequest {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              allowedSchemes.contains(scheme)
        else {
            throw AppRouteLinkError.unsupportedScheme
        }

        guard components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let host = components.host?.lowercased()
        else {
            throw AppRouteLinkError.unsupportedRoute
        }

        if host == "shareextension" {
            guard let appGroupID = components.queryItems?.first(where: { $0.name == "appGroupID" })?.value else {
                throw AppRouteLinkError.unsupportedRoute
            }
            return .shareExtension(appGroupID: appGroupID)
        }

        guard components.query == nil else {
            throw AppRouteLinkError.unsupportedRoute
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
                throw AppRouteLinkError.unsupportedRoute
            }
            switch pathComponents[0] {
            case "brand":
                return .mapBrand(try resourceID(from: pathComponents[1]))
            case "booth":
                return .mapBooth(try resourceID(from: pathComponents[1]))
            default:
                throw AppRouteLinkError.unsupportedRoute
            }

        case "archive":
            if pathComponents.isEmpty {
                return .archive
            }
            guard pathComponents.count == 2, pathComponents[0] == "photo" else {
                throw AppRouteLinkError.unsupportedRoute
            }
            return .archivePhoto(try resourceID(from: pathComponents[1]))

        case "pose":
            guard pathComponents.isEmpty else {
                throw AppRouteLinkError.unsupportedRoute
            }
            return .pose

        case "mypage":
            guard pathComponents.isEmpty else {
                throw AppRouteLinkError.unsupportedRoute
            }
            return .myPage

        case "notification":
            guard pathComponents.isEmpty else {
                throw AppRouteLinkError.unsupportedRoute
            }
            return .notificationList

        default:
            throw AppRouteLinkError.unsupportedRoute
        }
    }

    private func resourceID(
        from rawValue: String
    ) throws -> AppRouteRequest.ResourceID {
        guard let id = Int(rawValue), id > 0 else {
            throw AppRouteLinkError.invalidResourceID
        }
        return id
    }
}
