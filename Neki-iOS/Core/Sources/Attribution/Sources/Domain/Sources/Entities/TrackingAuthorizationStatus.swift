//
//  TrackingAuthorizationStatus.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/20/26.
//

public enum TrackingAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case unknown
}
