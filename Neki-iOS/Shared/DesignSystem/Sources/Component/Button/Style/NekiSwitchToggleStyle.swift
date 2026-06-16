//
//  NekiSwitchToggleStyle.swift
//  Neki-iOS
//
//  Created by Codex on 6/14/26.
//

import SwiftUI

public struct NekiSwitchToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label

                Spacer()

                Capsule()
                    .fill(configuration.isOn ? .primary300 : .gray100)
                    .frame(width: 52, height: 28)
                    .overlay {
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                            .offset(x: configuration.isOn ? 12 : -12)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
    }
}


// MARK: - NekiSwitchToggleStyle + Accessor

public extension ToggleStyle where Self == NekiSwitchToggleStyle {
    static var nekiSwitch: NekiSwitchToggleStyle { NekiSwitchToggleStyle() }
}
