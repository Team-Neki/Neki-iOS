//
//  ShadowStyle.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/22/26.
//

import SwiftUI

/// Neki 그림자 스타일입니다.
///
/// Figma 효과 스타일과 같은 그림자를 그립니다.
/// Figma의 블러는 SwiftUI 그림자 반경의 두 배로 퍼지므로, 반경은 Figma 블러의 절반으로 둡니다.
public enum ShadowStyle {
    /// 화면 위에 떠 있는 버튼과 검색 필드의 그림자입니다.
    ///
    /// - Figma: `btn_shadow` (#00000040, X 0, Y 2, 블러 8)
    case button

    var color: Color {
        switch self {
        case .button: .black.opacity(0.25)
        }
    }

    var radius: CGFloat {
        switch self {
        case .button: 4
        }
    }

    var x: CGFloat {
        switch self {
        case .button: .zero
        }
    }

    var y: CGFloat {
        switch self {
        case .button: 2
        }
    }
}
