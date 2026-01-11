//
//  NekiSheetDetent.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/28/25.
//

import Foundation

public enum NekiSheetDetent: Hashable {
    /// 감춤
    case hidden
    /// 화면 높이의 비율
    case fraction(CGFloat)
    /// 절대 높이
    case absolute(CGFloat)
    /// 화면 높이의 절반
    case medium
    /// 화면 최대 높이
    case large
    
    func resolve(in totalHeight: CGFloat, inset: CGFloat = 0) -> CGFloat {
        let availableHeight = max(0, totalHeight - inset)
        
        switch self {
        case .hidden: return .zero
        case .fraction(let value): return availableHeight * value
        case .absolute(let value): return min(value, availableHeight)
        case .medium: return availableHeight * 0.5
        case .large: return availableHeight
        }
    }
}
