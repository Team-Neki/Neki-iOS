//
//  DistanceFormatting.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/5/26.
//

import Foundation

protocol DistanceFormatting {
    func distance(from source: GeographicCoordinate, to destination: GeographicCoordinate) -> GeographicDistance
    func distance(from meters: Double) -> GeographicDistance
    func string(from distance: GeographicDistance) -> String
}
