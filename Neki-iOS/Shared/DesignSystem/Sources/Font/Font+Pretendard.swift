//
//  Font+Pretendard.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/22/25.
//

import SwiftUI

public enum FontStyle: CaseIterable {
    case doubleExtraLargeBold, doubleExtraLargeSemiBold
    case extraLargeMedium, extraLargeSemiBold
    case largeSemiBold, largeMedium, largeRegular
    case baseSemiBold, baseMedium, baseRegular
    case smallSemiBold, smallMedium, smallRegular
    case extraSmallSemiBold, extraSmallMedium, extraSmallRegular
    
    var fontSize: CGFloat {
        switch self {
        case .doubleExtraLargeBold, .doubleExtraLargeSemiBold: 24
        case .extraLargeMedium, .extraLargeSemiBold: 20
        case .largeSemiBold, .largeMedium, .largeRegular: 18
        case .baseSemiBold, .baseMedium, .baseRegular: 16
        case .smallSemiBold, .smallMedium, .smallRegular: 14
        case .extraSmallSemiBold, .extraSmallMedium, .extraSmallRegular: 12
        }
    }
    
    var fontWeight: Font.Weight {
        switch self {
        case .doubleExtraLargeBold: .bold
        case .doubleExtraLargeSemiBold, .extraSmallSemiBold, .extraLargeSemiBold, .smallSemiBold, .largeSemiBold, .baseSemiBold: .semibold
        case .extraSmallMedium, .extraLargeMedium, .smallMedium, .largeMedium, .baseMedium: .medium
        case .extraSmallRegular, .smallRegular, .largeRegular, .baseRegular: .regular
        }
    }
    
    var lineHeight: CGFloat {
        switch self {
        case .doubleExtraLargeBold, .doubleExtraLargeSemiBold: 36
        case .extraLargeMedium, .extraLargeSemiBold, .largeSemiBold, .largeMedium, .largeRegular: 28
        case .baseSemiBold, .baseMedium, .baseRegular: 24
        case .smallSemiBold, .smallMedium, .smallRegular: 20
        case .extraSmallMedium, .extraSmallRegular, .extraSmallSemiBold: 16
        }
    }
    
    var letterSpacing: CGFloat { .zero }
    
    var fontName: String {
        switch self {
        case .doubleExtraLargeBold: "Pretendard-Bold"
        case .baseSemiBold, .largeSemiBold, .smallSemiBold, .extraLargeSemiBold, .extraSmallSemiBold, .doubleExtraLargeSemiBold: "Pretendard-SemiBold"
        case .baseMedium, .largeMedium, .smallMedium, .extraLargeMedium, .extraSmallMedium: "Pretendard-Medium"
        case .baseRegular, .largeRegular, .smallRegular, .extraSmallRegular: "Pretendard-Regular"
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
            .font(.custom(style.fontName, size: style.fontSize))
            .fontWeight(style.fontWeight)
            .lineSpacing(calculatedLineSpacing)
            .tracking(calculatedTracking)
    }
}

public extension View where Self == Text {
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
        .custom(style.fontName, size: style.fontSize).weight(style.fontWeight)
    }
}
