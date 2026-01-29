//
//  Int.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/28/26.
//

import Foundation

public extension Int {
    var distanceString: String {
        guard self > 1000 else { return "\(self)m" }
        let km = Double(self) / 1000.0
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        let value = formatter.string(from: NSNumber(value: km)) ?? "\(km)"
        return "\(value)km"
    }
}
