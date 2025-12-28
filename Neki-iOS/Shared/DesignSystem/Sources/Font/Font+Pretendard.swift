//
//  Font+Pretendard.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/22/25.
//

import SwiftUI

public enum FontStyle: CaseIterable {
    case title24Bold, title24SemiBold
    case title20Bold, title20SemiBold, title20Medium
    case title18Bold, title18SemiBold, title18Medium, title18Regular
    case body16SemiBold, body16Medium, body16Regular
    case body14SemiBold, body14Medium, body14Regular
    case caption12SemiBold, caption12Medium, caption12Regular
    
    var fontSize: CGFloat {
        switch self {
        case .title24Bold, .title24SemiBold: 24
        case .title20Bold, .title20SemiBold, .title20Medium: 20
        case .title18Bold, .title18SemiBold, .title18Medium, .title18Regular: 18
        case .body16SemiBold, .body16Medium, .body16Regular: 16
        case .body14SemiBold, .body14Medium, .body14Regular: 14
        case .caption12SemiBold, .caption12Medium, .caption12Regular: 12
        }
    }
    
    var textStyle: Font.TextStyle {
        switch self {
        case .title24Bold, .title24SemiBold, .title20Bold, .title20SemiBold, .title20Medium, .title18Bold, .title18SemiBold, .title18Medium, .title18Regular: .title
        case .body16SemiBold, .body16Medium, .body16Regular, .body14SemiBold, .body14Medium, .body14Regular: .body
        case .caption12SemiBold, .caption12Medium, .caption12Regular: .caption
        }
    }
    
    var lineHeight: CGFloat {
        switch self {
        case .title24Bold, .title24SemiBold: 36
        case .title20Bold, .title20SemiBold, .title20Medium, .title18Bold, .title18SemiBold, .title18Medium, .title18Regular: 28
        case .body16SemiBold, .body16Medium, .body16Regular: 24
        case .body14SemiBold, .body14Medium, .body14Regular: 20
        case .caption12SemiBold, .caption12Medium, .caption12Regular: 16
        }
    }
    
    var letterSpacing: CGFloat { .zero }
    
    var fontName: String {
        switch self {
        case .title24Bold, .title20Bold, .title18Bold: "Pretendard-Bold"
        case .title24SemiBold, .title20SemiBold, .title18SemiBold, .body16SemiBold, .body14SemiBold, .caption12SemiBold: "Pretendard-SemiBold"
        case .title20Medium, .title18Medium, .body16Medium, .body14Medium, .caption12Medium: "Pretendard-Medium"
        case .title18Regular, .body16Regular, .body14Regular, .caption12Regular: "Pretendard-Regular"
        }
    }
}

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
