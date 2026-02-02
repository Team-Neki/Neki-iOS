//
//  MapTile.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/26/26.
//

import Foundation

public struct MapTile: Equatable, Hashable, Sendable {
    public static let kDefaultZoomLevel: Int = 15
    public let x, y, z: Int
    
    public init(x: Int, y: Int, z: Int = kDefaultZoomLevel) {
        self.x = x
        self.y = y
        self.z = z
    }
}
