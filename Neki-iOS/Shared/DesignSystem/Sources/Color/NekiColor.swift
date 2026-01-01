//
//  NekiColor.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/1/26.
//

import SwiftUI

public typealias Hex = UInt


// MARK: - Color + Hex

extension Color {
    init(hex: Hex, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: opacity
        )
    }
}


// MARK: - UIColor + Hex

extension UIColor {
    convenience init(hex: Hex, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 08) & 0xff) / 255,
            blue: CGFloat((hex >> 00) & 0xff) / 255,
            alpha: alpha
        )
    }
}

