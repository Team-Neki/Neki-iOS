//
//  NekiWarningAlertModifier.swift
//  Neki-iOS
//
//  Created by OneTen on 1/5/26.
//

import SwiftUI

struct NekiWarningAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    let titleMessage: String
    let onExit: (() -> Void)
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)
            
            if isPresented {
                Color.gray900.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
                
                NekiWarningModal(
                    titleMessage: titleMessage,
                    onExit: {
                        onExit()
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
    func nekiWarningAlert(
        isPresented: Binding<Bool>,
        titleMessage: String,
        onExit: @escaping (() -> Void)
    ) -> some View {
        self.modifier(NekiWarningAlertModifier(
            isPresented: isPresented,
            titleMessage: titleMessage,
            onExit: onExit
        ))
    }
}
