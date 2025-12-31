//
//  GeographicCoordinate.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

public struct GeographicCoordinate: Hashable, Sendable {
    /// 위도 (가로선)
    public let latitude: Double
    /// 경도 (세로선)
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        precondition(GeographicLimit.isValidLatitude(latitude), "위도 값 \(latitude)이 유효한 범위를 벗어났습니다. 유효 범위: \(GeographicLimit.latitudeRange)")
        precondition(GeographicLimit.isValidLongitude(longitude), "경도 값 \(longitude)이 유효한 범위를 벗어났습니다. 유효 범위 :\(GeographicLimit.longitudeRange)")
        
        self.latitude = latitude
        self.longitude = longitude
    }
}
