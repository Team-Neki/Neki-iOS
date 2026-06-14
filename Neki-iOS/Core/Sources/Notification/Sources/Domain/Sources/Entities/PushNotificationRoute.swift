//
//  PushNotificationRoute.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/14/26.
//

import Foundation

public enum PushNotificationRoute: Equatable, Sendable {
    public typealias ResourceID = Int

    case map
    case mapBrand(ResourceID)
    case mapBooth(ResourceID)
    case archive
    case archivePhoto(ResourceID)
    case pose
    case myPage
}

public enum PushNotificationLinkError: Error, Equatable {
    case invalidResourceID
    case invalidURL
    case unsupportedScheme
    case unsupportedRoute
}

