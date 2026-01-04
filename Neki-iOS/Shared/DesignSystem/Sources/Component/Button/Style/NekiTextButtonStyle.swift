//
//  NekiTextButtonStyle.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/3/26.
//

import SwiftUI

public struct NekiTextButtonStyle: ButtonStyle {
    public enum Role { case secondary, primary }
    public enum Style { case normal, dropdown }
    
    let role: Role
    let style: Style
    
    @Environment(\.isEnabled) private var isEnabled: Bool
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: .zero) {
            configuration.label
            
            if case .dropdown = style {
                Image(.iconChevronDown)
                    .foregroundStyle(.gray300)
            }
        }
        .nekiFont(style == .normal ? .body16SemiBold : .body14SemiBold)
        .padding(.vertical, 10)
        .foregroundStyle(foregroundColor)
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .animation(.easeInOut, value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        guard isEnabled else { return .gray200 }
        guard case .normal = style else { return .gray800 }
        switch role {
        case .secondary: return .gray800
        case .primary: return .primary500
        }
    }
}


// MARK: - NekiTextButtonStyle + Accessor

public extension ButtonStyle where Self == NekiTextButtonStyle {
    static func nekiText(_ role: NekiTextButtonStyle.Role = .primary, _ style: NekiTextButtonStyle.Style = .normal) -> NekiTextButtonStyle {
        NekiTextButtonStyle(role: role, style: style)
    }
}

public extension PrimitiveButtonStyle {
    static func nekiText(_ role: NekiTextButtonStyle.Role = .primary, _ style: NekiTextButtonStyle.Style = .normal) -> NekiTextButtonStyle {
        NekiTextButtonStyle(role: role, style: style)
    }
}
