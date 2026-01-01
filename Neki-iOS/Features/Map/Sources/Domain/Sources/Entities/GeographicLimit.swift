//
//  GeographicLimit.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/30/25.
//

import Foundation

/// 지리 좌표 시스템의 유효 범위를 정의합니다.
enum GeographicLimit {
    static let latitudeRange: ClosedRange<Double> = -90.0...90.0
    static let longitudeRange: ClosedRange<Double> = -180.0...180.0
    
    static func isValidLatitude(_ latitude: Double) -> Bool { latitudeRange.contains(latitude) }
    static func isValidLongitude(_ longitude: Double) -> Bool { longitudeRange.contains(longitude) }
}
