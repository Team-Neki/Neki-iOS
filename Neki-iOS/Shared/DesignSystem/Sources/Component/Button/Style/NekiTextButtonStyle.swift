//
//  NekiTextButtonStyle.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/3/26.
//

import SwiftUI

public struct NekiTextButtonStyle: ButtonStyle {
    private enum Constants {
        static let dropdownIcon: String = "chevron.down"
    }
    
    public enum Role { case secondary, primary }
    public enum Variant { case normal, dropdown }
    
    let role: Role
    let variant: Variant
    
    @Environment(\.isEnabled) private var isEnabled: Bool
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: .zero) {
            configuration.label
            
            if case .dropdown = variant {
                Image(systemName: Constants.dropdownIcon)
                    .foregroundStyle(.gray300)
            }
        }
        .nekiFont(variant == .normal ? .body16SemiBold : .body14SemiBold)
        .padding(.vertical, 10)
        .foregroundStyle(foregroundColor)
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .animation(.easeInOut, value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        guard isEnabled else { return .gray200 }
        guard case .normal = variant else { return .gray800 }
        switch role {
        case .secondary: return .gray800
        case .primary: return .primary500
        }
    }
}


// MARK: - NekiTextButtonStyle + Accessor

public extension ButtonStyle where Self == NekiTextButtonStyle {
    static func nekiText(_ role: NekiTextButtonStyle.Role = .primary, _ variant: NekiTextButtonStyle.Variant = .normal) -> NekiTextButtonStyle {
        NekiTextButtonStyle(role: role, variant: variant)
    }
}

public extension PrimitiveButtonStyle {
    static func nekiText(_ role: NekiTextButtonStyle.Role = .primary, _ variant: NekiTextButtonStyle.Variant = .normal) -> NekiTextButtonStyle {
        NekiTextButtonStyle(role: role, variant: variant)
    }
}
