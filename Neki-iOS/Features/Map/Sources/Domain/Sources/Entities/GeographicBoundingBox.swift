//
//  GeographicBoundingBox.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

struct GeographicBoundingBox: Equatable {
    let minLatitude: Double
    let minLongitude: Double
    let maxLatitude: Double
    let maxLongitude: Double
    
    init(minLatitude: Double, minLongitude: Double, maxLatitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.minLongitude = minLongitude
        self.maxLatitude = maxLatitude
        self.maxLongitude = maxLongitude
    }
}
