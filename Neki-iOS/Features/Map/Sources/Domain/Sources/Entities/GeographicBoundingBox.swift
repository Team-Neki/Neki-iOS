//
//  GeographicBoundingBox.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

public struct GeographicBoundingBox: Equatable, Sendable {
    let minLatitude: Double
    let minLongitude: Double
    let maxLatitude: Double
    let maxLongitude: Double
    
    var center: GeographicCoordinate { .init(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2) }
    
    init(minLatitude: Double, minLongitude: Double, maxLatitude: Double, maxLongitude: Double) {
        precondition(GeographicLimit.isValidLatitude(minLatitude), "최소 위도\(minLatitude)는 유효하지 않습니다.")
        precondition(GeographicLimit.isValidLatitude(maxLatitude), "최대 위도\(maxLatitude)는 유효하지 않습니다.")
        precondition(GeographicLimit.isValidLongitude(minLongitude), "최소 경도\(minLongitude)는 유효하지 않습니다.")
        precondition(GeographicLimit.isValidLongitude(maxLongitude), "최대 경도\(maxLongitude)는 유효하지 않습니다.")
        precondition(minLatitude <= maxLatitude, "최소 위도는 최대 위도보다 작거나 같아야 합니다.")
        precondition(minLongitude <= maxLongitude, "최소 경도는 최대 경도보다 작거나 같아야 합니다.")
        
        self.minLatitude = minLatitude
        self.minLongitude = minLongitude
        self.maxLatitude = maxLatitude
        self.maxLongitude = maxLongitude
    }
    
    func contains(_ coordinate: GeographicCoordinate) -> Bool {
        return coordinate.latitude >= minLatitude &&
               coordinate.latitude <= maxLatitude &&
               coordinate.longitude >= minLongitude &&
               coordinate.longitude <= maxLongitude
    }
}
