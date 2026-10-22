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
    /// 화면 최대 높이. 위쪽 여백(`topInset`)을 두면 그만큼 남깁니다.
    case large
    
    /// 시트를 그리는 영역의 높이에 맞춰 이 높이를 pt로 바꿉니다.
    ///
    /// - Parameters:
    ///   - totalHeight: 시트를 그리는 영역의 높이
    ///   - inset: 시트 아래에 남길 여백
    ///   - topInset: 시트를 가장 높이 올렸을 때(`large`) 위에 남길 여백. 다른 높이에는 쓰지 않습니다.
    func resolve(in totalHeight: CGFloat, inset: CGFloat = 0, topInset: CGFloat = 0) -> CGFloat {
        let availableHeight = max(0, totalHeight - inset)
        
        switch self {
        case .hidden: return .zero
        case .fraction(let value): return availableHeight * value
        case .absolute(let value): return min(value, availableHeight)
        case .medium: return availableHeight * 0.5
        case .large: return max(0, availableHeight - topInset)
        }
    }
}
