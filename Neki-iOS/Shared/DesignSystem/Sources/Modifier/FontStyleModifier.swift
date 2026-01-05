//
//  FontStyleModifier.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/5/26.
//

import SwiftUI

struct FontStyleModifier: ViewModifier {
    public let style: FontStyle
    
    public init(style: FontStyle) {
        self.style = style
    }
    
    private var calculatedLineSpacing: CGFloat { style.lineHeight - style.fontSize }
    private var calculatedTracking: CGFloat { style.letterSpacing }
    
    func body(content: Content) -> some View {
        content
            .font(.custom(style.fontName, size: style.fontSize, relativeTo: style.textStyle))
            .lineSpacing(calculatedLineSpacing)
            .tracking(calculatedTracking)
    }
}

public extension View {
    /// Neki 폰트 스타일을 적용합니다.
    func nekiFont(_ style: FontStyle) -> some View {
        modifier(FontStyleModifier(style: style))
    }
}

public extension Font {
    /// Neki 폰트를 사용합니다.
    ///
    /// - Attention: Neki 스타일을 제외한 폰트만을 사용하려고 할때 유용합니다. 일부 스타일은 누락될 수 있습니다.
    ///     * 줄간격
    ///     * 자간
    static func neki(_ style: FontStyle) -> Self {
        .custom(style.fontName, size: style.fontSize, relativeTo: style.textStyle)
    }
}
