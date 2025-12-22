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
