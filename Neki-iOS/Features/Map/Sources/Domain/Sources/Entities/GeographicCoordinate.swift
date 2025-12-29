//
//  GeographicCoordinate.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

public struct GeographicCoordinate: Hashable {
    /// 위도 (가로선)
    public let latitude: Double
    /// 경도 (세로선)
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
