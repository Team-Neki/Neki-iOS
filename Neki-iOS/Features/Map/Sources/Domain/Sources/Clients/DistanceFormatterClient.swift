//
//  DistanceFormatterClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/5/26.
//

import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct DistanceFormatterClient {
    public var distance: @Sendable (_ source: GeographicCoordinate, _ destination: GeographicCoordinate) -> GeographicDistance = { _, _ in GeographicDistance(meters: 0) }
    public var distanceFromMeters: @Sendable (_ meters: Double) -> GeographicDistance = { meters in GeographicDistance(meters: meters) }
    public var string: @Sendable (_ distance: GeographicDistance?) -> String = { _ in "" }
}


// MARK: - DistanceFormatterClient + DependencyKey

extension DistanceFormatterClient: DependencyKey {
    public static var liveValue: DistanceFormatterClient = {
        @Dependency(\.distanceFormatter) var distanceFormatter
        
        return DistanceFormatterClient { source, destination in
            distanceFormatter.distance(from: source, to: destination)
        } distanceFromMeters: { meters in
            distanceFormatter.distance(from: meters)
        } string: { distance in
            guard let distance else { return "" }
            guard distance.isNearby == false else { return "0m" }
            return distanceFormatter.string(from: distance)
        }
    }()
}


// MARK: - DistanceFormatterClient + DependencyValues

extension DependencyValues {
    public var distanceFormatterClient: DistanceFormatterClient {
        get { self[DistanceFormatterClient.self] }
        set { self[DistanceFormatterClient.self] = newValue }
    }
}
