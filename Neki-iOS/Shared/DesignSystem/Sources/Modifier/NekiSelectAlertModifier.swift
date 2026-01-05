//
//  NekiSelectAlertModifier.swift
//  Neki-iOS
//
//  Created by OneTen on 1/5/26.
//

import SwiftUI

struct NekiSelectAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    let style: NekiSelectModal.AlertStyle
    let items: [String]?
    let onExit: () -> Void
    let onSelect: (Int) -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)
            
            if isPresented {
                Color.gray900.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(1)
                
                NekiSelectModal(
                    style: style,
                    items: items,
                    onExit: {
                        onExit()
                    },
                    onSelect: { index in
                        onSelect(index)
                    }
                )
                .padding(.horizontal, 28)
                .zIndex(2)
                .transition(.scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.7)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

public extension View {
    func nekiSelectAlert(
        isPresented: Binding<Bool>,
        style: NekiSelectModal.AlertStyle,
        items: [String]? = nil,
        onExit: @escaping () -> Void,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        self.modifier(NekiSelectAlertModifier(
            isPresented: isPresented,
            style: style,
            items: items,
            onExit: onExit,
            onSelect: onSelect
        ))
    }
}
