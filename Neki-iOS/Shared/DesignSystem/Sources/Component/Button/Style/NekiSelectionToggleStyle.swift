//
//  NekiSelectionToggleStyle.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/2/26.
//

import SwiftUI

public struct NekiSelectionToggleStyle: ToggleStyle {
    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                if configuration.isOn {
                    Image(.iconCheckmark)
                        .foregroundStyle(.primary400)
                }
                
                configuration.label
                    .nekiFont(configuration.isOn ? .body16SemiBold : .body16Medium)
                    .foregroundStyle(configuration.isOn ? .gray900 : .gray600)
                
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }
}


// MARK: - NekiSelectionToggleStyle + Accessor

public extension ToggleStyle where Self == NekiSelectionToggleStyle {
    static var nekiSelection: NekiSelectionToggleStyle { NekiSelectionToggleStyle() }
}
