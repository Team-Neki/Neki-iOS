//
//  NekiChipButtonStyle.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/2/26.
//

import SwiftUI

public struct NekiChipButtonStyle: ButtonStyle {
    public enum Style { case normal, dropdown }
    public enum Shape { case roundedRectangle, capsule }
    
    let isHighlighted: Bool
    let style: Style
    let shape: Shape
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.label
            
            if case .dropdown = style {
                Image(.iconChevronDown)
                    .foregroundStyle(.gray500)
            }
        }
        .nekiFont(isHighlighted ? .body14SemiBold : .body14Medium)
        .padding(.leading, 12)
        .padding(.trailing, style == .dropdown ? 8 : 12)
        .padding(.vertical, 12)
        .background(isHighlighted ? .gray800 : .gray50)
        .foregroundStyle(isHighlighted ? .white : .gray700)
        .clipShape(RoundedRectangle(cornerRadius: shape == .roundedRectangle ? 12 : 999))
    }
}


// MARK: - NekiChipButtonStyle + Accessor

public extension ButtonStyle where Self == NekiChipButtonStyle {
    static func nekiChip(
        isHighlighted: Bool,
        shape: NekiChipButtonStyle.Shape = .roundedRectangle,
        style: NekiChipButtonStyle.Style = .normal
    ) -> NekiChipButtonStyle {
        NekiChipButtonStyle(isHighlighted: isHighlighted, style: style, shape: shape)
    }
}

public extension PrimitiveButtonStyle {
    static func nekiChip(
        isHighlighted: Bool,
        shape: NekiChipButtonStyle.Shape = .roundedRectangle,
        style: NekiChipButtonStyle.Style = .normal
    ) -> NekiChipButtonStyle {
        NekiChipButtonStyle(isHighlighted: isHighlighted, style: style, shape: shape)
    }
}
