//
//  NekiAlertModifier.swift
//  Neki-iOS
//
//  Created by OneTen on 1/5/26.
//

import SwiftUI

struct NekiAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    let style: NekiAlertModal.AlertStyle
    let titleMessage: String
    let subTitleMessage: String
    let confirmText: String
    let cancelText: String?
    let isProcessing: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)
            
            if isPresented {
                Color.gray900.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(1)
                
                NekiAlertModal(
                    style: style,
                    onConfirm: {
                        onConfirm()
                    },
                    onCancel: {
                        onCancel()
                    },
                    titleMessage: titleMessage,
                    subTitleMessage: subTitleMessage,
                    confirmText: confirmText,
                    cancelText: cancelText,
                    isProcessing: isProcessing
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
    func nekiAlert(
        isPresented: Binding<Bool>,
        style: NekiAlertModal.AlertStyle = .plain,
        titleMessage: String,
        subTitleMessage: String,
        confirmText: String = "확인",
        cancelText: String? = nil,
        isProcessing: Bool = false,
        onConfirm: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(NekiAlertModifier(
            isPresented: isPresented,
            style: style,
            titleMessage: titleMessage,
            subTitleMessage: subTitleMessage,
            confirmText: confirmText,
            cancelText: cancelText,
            isProcessing: isProcessing,
            onConfirm: onConfirm,
            onCancel: onCancel
        ))
    }
}
