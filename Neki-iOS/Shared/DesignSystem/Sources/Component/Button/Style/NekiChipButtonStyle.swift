//
//  NekiChipButtonStyle.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/2/26.
//

import SwiftUI

public struct NekiChipButtonStyle: ButtonStyle {
    private enum Constants {
        static let dropdownIcon: String = "chevron.down"
    }
    
    public enum Variant { case normal, dropdown }
    public enum Shape { case roundedRectangle, capsule }
    
    let isHighlighted: Bool
    let variant: Variant
    let shape: Shape
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: NekiMetric.spacing4) {
            configuration.label
            
            if case .dropdown = variant {
                Image(systemName: Constants.dropdownIcon)
            }
        }
        .nekiFont(isHighlighted ? .body14SemiBold : .body14Medium)
        .padding(.leading, NekiMetric.padding12)
        .padding(.trailing, variant == .dropdown ? NekiMetric.padding8 : NekiMetric.padding12)
        .padding(.vertical, NekiMetric.padding12)
        .background(isHighlighted ? .gray800 : .gray50)
        .foregroundStyle(isHighlighted ? .white : .gray700)
        .clipShape(RoundedRectangle(cornerRadius: shape == .roundedRectangle ? NekiMetric.radius12 : NekiMetric.radius999))
    }
}


// MARK: - NekiChipButtonStyle + Accessor

public extension ButtonStyle where Self == NekiChipButtonStyle {
    static func nekiChip(
        isHighlighted: Bool,
        shape: NekiChipButtonStyle.Shape = .roundedRectangle,
        variant: NekiChipButtonStyle.Variant = .normal
    ) -> NekiChipButtonStyle {
        NekiChipButtonStyle(isHighlighted: isHighlighted, variant: variant, shape: shape)
    }
}

public extension PrimitiveButtonStyle {
    static func nekiChip(
        isHighlighted: Bool,
        shape: NekiChipButtonStyle.Shape = .roundedRectangle,
        variant: NekiChipButtonStyle.Variant = .normal
    ) -> NekiChipButtonStyle {
        NekiChipButtonStyle(isHighlighted: isHighlighted, variant: variant, shape: shape)
    }
}
