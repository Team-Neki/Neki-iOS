//
//  NekiColor.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/1/26.
//

import SwiftUI

public typealias ColorHexCode = UInt


// MARK: - Color + Hex

extension Color {
    init(hex: ColorHexCode, opacity: Double = 1.0) {
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
    convenience init(hex: ColorHexCode, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 08) & 0xff) / 255,
            blue: CGFloat((hex >> 00) & 0xff) / 255,
            alpha: alpha
        )
    }
}

/// Neki 컬러 팔레트
public enum NekiColor: ColorHexCode {
    // MARK: Grayscale
    /// Gray 25
    /// - Hex: 0xF9FAFA
    case gray25 = 0xF9FAFA
    
    /// Gray 50
    /// - Hex: 0xEEF1F1
    case gray50 = 0xEEF1F1
    
    /// Gray 75
    /// - Hex: 0xE3E4E8
    case gray75 = 0xE3E4E8
    
    /// Gray 100
    /// - Hex: 0xCDCED5
    case gray100 = 0xCDCED5
    
    /// Gray 200
    /// - Hex: 0xB7B9C3
    case gray200 = 0xB7B9C3
    
    /// Gray 300
    /// - Hex: 0xA0A3B0
    case gray300 = 0xA0A3B0
    
    /// Gray 400
    /// - Hex: 0x8A8E9E
    case gray400 = 0x8A8E9E
    
    /// Gray 500
    /// - Hex: 0x74788B
    case gray500 = 0x74788B
    
    /// Gray 600
    /// - Hex: 0x616575
    case gray600 = 0x616575
    
    /// Gray 700
    /// - Hex: 0x4F525F
    case gray700 = 0x4F525F
    
    /// Gray 800
    /// - Hex: 0x3C3E48
    case gray800 = 0x3C3E48
    
    /// Gray 900
    /// - Hex: 0x202227
    case gray900 = 0x202227
    
    // MARK: Primary
    /// Primary 25
    /// - Hex: 0xFFECEB
    case primary25 = 0xFFECEB
    
    /// Primary 50
    /// - Hex: 0xFFDAD6
    case primary50 = 0xFFDAD6
    
    /// Primary 100
    /// - Hex: 0xFFC7C2
    case primary100 = 0xFFC7C2
    
    /// Primary 200
    /// - Hex: 0xFFA299
    case primary200 = 0xFFA299
    
    /// Primary 300
    /// - Hex: 0xFF786B
    case primary300 = 0xFF786B
    
    /// Primary 400
    /// - Hex: 0xFF5647
    case primary400 = 0xFF5647
    
    /// Primary 500
    /// - Hex: 0xFF311F
    case primary500 = 0xFF311F
    
    /// Primary 600
    /// - Hex: 0xF51500
    case primary600 = 0xF51500
    
    /// Primary 700
    /// - Hex: 0xCC1100
    case primary700 = 0xCC1100
    
    /// Primary 800
    /// - Hex: 0xA30E00
    case primary800 = 0xA30E00
    
    /// Primary 900
    /// - Hex: 0x7A0A00
    case primary900 = 0x7A0A00
    
    public var color: Color { Color(hex: rawValue) }
}


// MARK: - Color + NekiColor

public extension ShapeStyle where Self == Color {
    // MARK: - Grayscale
    static var gray25: Color { NekiColor.gray25.color }
    static var gray50: Color { NekiColor.gray50.color }
    static var gray75: Color { NekiColor.gray75.color }
    static var gray100: Color { NekiColor.gray100.color }
    static var gray200: Color { NekiColor.gray200.color }
    static var gray300: Color { NekiColor.gray300.color }
    static var gray400: Color { NekiColor.gray400.color }
    static var gray500: Color { NekiColor.gray500.color }
    static var gray600: Color { NekiColor.gray600.color }
    static var gray700: Color { NekiColor.gray700.color }
    static var gray800: Color { NekiColor.gray800.color }
    static var gray900: Color { NekiColor.gray900.color }
    
    // MARK: - Primary
    static var primary25: Color { NekiColor.primary25.color }
    static var primary50: Color { NekiColor.primary50.color }
    static var primary100: Color { NekiColor.primary100.color }
    static var primary200: Color { NekiColor.primary200.color }
    static var primary300: Color { NekiColor.primary300.color }
    static var primary400: Color { NekiColor.primary400.color }
    static var primary500: Color { NekiColor.primary500.color }
    static var primary600: Color { NekiColor.primary600.color }
    static var primary700: Color { NekiColor.primary700.color }
    static var primary800: Color { NekiColor.primary800.color }
    static var primary900: Color { NekiColor.primary900.color }
    
    // MARK: - Utils
    /// 동적으로 색상을 선택해야 하거나 Hex 코드를 써야 할 때만 함수 사용
    static func neki(_ type: NekiColor) -> Color { type.color }
    static func hex(_ code: ColorHexCode) -> Color { Color(hex: code) }
}
