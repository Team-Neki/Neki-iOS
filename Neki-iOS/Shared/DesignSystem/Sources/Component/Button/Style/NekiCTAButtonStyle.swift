//
//  NekiCTAButtonStyle.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/2/26.
//

import SwiftUI

public struct NekiCTAButtonStyle: ButtonStyle {
    public enum Role { case secondary, primary }
    
    let role: Role
    
    @Environment(\.isEnabled) private var isEnabled: Bool
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .nekiFont(.body16SemiBold)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
    
    private var backgroundColor: Color {
        guard isEnabled else { return .hex(0xF5BEB7) }
        switch role {
        case .secondary: return .gray50
        case .primary: return .primary400
        }
    }
    
    private var foregroundColor: Color {
        guard isEnabled else { return .white }
        switch role {
        case .secondary: return .gray300
        case .primary: return .white
        }
    }
}


// MARK: - NekiCTAButtonStyle + Accessor

public extension ButtonStyle where Self == NekiCTAButtonStyle  {
    static func nekiCTA(_ role: NekiCTAButtonStyle.Role = .primary) -> NekiCTAButtonStyle { NekiCTAButtonStyle(role: role) }
}

public extension PrimitiveButtonStyle {
    static func nekiCTA(_ role: NekiCTAButtonStyle.Role = .primary) -> NekiCTAButtonStyle { NekiCTAButtonStyle(role: role) }
}
