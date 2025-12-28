//
//  NekiSheetDetent.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/28/25.
//

import Foundation

public enum NekiSheetDetent: Hashable {
    /// 화면 높이의 비율
    case fraction(CGFloat)
    /// 절대 높이
    case absolute(CGFloat)
    /// 화면 높이의 절반
    case medium
    /// 화면 최대 높이
    case large
    
    func resolve(in height: CGFloat) -> CGFloat {
        switch self {
        case .fraction(let value): return height * value
        case .absolute(let value): return value
        case .medium: return height * 0.5
        case .large: return height
        }
    }
}
