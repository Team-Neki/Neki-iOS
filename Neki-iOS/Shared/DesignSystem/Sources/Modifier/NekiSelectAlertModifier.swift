//
//  NekiSelectAlertModifier.swift
//  Neki-iOS
//
//  Created by OneTen on 1/5/26.
//

import SwiftUI

struct NekiSelectAlertModifier<AlertContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let alertContent: AlertContent
    
    init(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> AlertContent
    ) {
        self._isPresented = isPresented
        self.alertContent = content()
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)
            
            if isPresented {
                Color.gray900.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(1)
                    .onTapGesture {
                        isPresented = false
                    }
                
                alertContent
                    .padding(.horizontal, 28)
                    .zIndex(2)
                    .transition(.scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.7)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

public extension View {
    func nekiSelectAlert<Content: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        onExit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(NekiSelectAlertModifier(
            isPresented: isPresented,
            content: {
                NekiSelectContainer(
                    title: title,
                    onExit: onExit,
                    content: content
                )
            }
        ))
    }
    
    func nekiSelectAlert(
        isPresented: Binding<Bool>,
        style: NekiSelectModal.AlertStyle,
        items: [String]? = nil,
        onExit: @escaping () -> Void,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        let title = (style == .map) ? "길찾기" : nil
        
        return self.nekiSelectAlert(
            isPresented: isPresented,
            title: title,
            onExit: onExit
        ) {
            NekiSelectModal(
                style: style,
                items: items,
                onSelect: onSelect
            )
        }
    }
}
