//
//  PhotoBoothDistanceFormatter.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/5/26.
//

import Foundation
import CoreLocation
import Dependencies

final class PhotoBoothDistanceFormatter {
    private let measurementFormatter: MeasurementFormatter
    
    init(locale: Locale = .current) {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.locale = locale
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.maximumFractionDigits = 1
        formatter.numberFormatter = numberFormatter
        
        self.measurementFormatter = formatter
    }
}


// MARK: - DistanceFormatting Conformation

extension PhotoBoothDistanceFormatter: DistanceFormatting {
    func distance(from source: GeographicCoordinate, to destination: GeographicCoordinate) -> GeographicDistance {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distanceMeters = sourceLocation.distance(from: destinationLocation)
        return .init(meters: distanceMeters)
    }
    
    func distance(from meters: Double) -> GeographicDistance { .init(meters: meters) }
    
    func string(from distance: GeographicDistance) -> String {
        let measurement = Measurement(value: distance.meters, unit: UnitLength.meters)
        return measurementFormatter.string(from: measurement)
    }
}


// MARK: - PhotoBoothDistanceFormatter + DependencyKey

enum DistanceFormatterKey: DependencyKey {
    static var liveValue: DistanceFormatting = PhotoBoothDistanceFormatter()
}


// MARK: - PhotoBoothDistanceFormatter + DependencyValues

extension DependencyValues {
    var distanceFormatter: any DistanceFormatting {
        get { self[DistanceFormatterKey.self] }
        set { self[DistanceFormatterKey.self] = newValue }
    }
}
