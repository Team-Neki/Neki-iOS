//
//  ShadowStyleModifier.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/22/26.
//

import SwiftUI

struct ShadowStyleModifier: ViewModifier {
    let style: ShadowStyle
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: isVisible ? style.color : .clear, radius: style.radius, x: style.x, y: style.y)
    }
}

public extension View {
    /// Neki 그림자 스타일을 적용합니다.
    ///
    /// - Parameters:
    ///   - style: 적용할 그림자 스타일
    ///   - isVisible: 그림자를 그릴지 여부. 숨길 때도 뷰 계층이 바뀌지 않도록 그림자 색만 투명하게 바꿉니다.
    func nekiShadow(_ style: ShadowStyle, isVisible: Bool = true) -> some View {
        modifier(ShadowStyleModifier(style: style, isVisible: isVisible))
    }
}
