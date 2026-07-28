//
//  AppRouteRequest.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation

enum AppRouteRequest: Equatable, Sendable {
    typealias ResourceID = Int

    case map
    case mapBrand(ResourceID)
    case mapBooth(ResourceID)
    case archive
    case archivePhoto(ResourceID)
    case pose
    case myPage
    case notificationList
    case shareExtension(appGroupID: String)
}

enum AppRouteLinkError: Error, Equatable {
    case invalidResourceID
    case invalidURL
    case unsupportedScheme
    case unsupportedRoute
}
