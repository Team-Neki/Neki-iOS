//
//  GeographicDistance.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/5/26.
//

import Foundation

/// POI간 거리값을 의미합니다.
public struct GeographicDistance: Sendable, Equatable, Comparable, Hashable {
    public static let nearbyThreshold: Double = 1.0
    
    public let meters: Double
    public var isNearby: Bool { meters < Self.nearbyThreshold }
    
    public init(meters: Double) { self.meters = meters }
    public init(meters: Int) { self.meters = Double(meters) }
    
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.meters < rhs.meters }
}
