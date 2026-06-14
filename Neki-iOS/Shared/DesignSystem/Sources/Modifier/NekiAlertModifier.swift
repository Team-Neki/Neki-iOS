//
//  NekiAlertModifier.swift
//  Neki-iOS
//
//  Created by OneTen on 1/5/26.
//

import SwiftUI

struct NekiAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    let style: NekiAlertStyle
    let contentStyle: NekiAlertContentStyle
    let title: String
    let subtitle: String
    
    // 버튼 텍스트
    let confirmText: String
    let cancelText: String?
    let secondaryText: String?
    
    let isProcessing: Bool
    let hasIcon: Bool
    
    // 액션 클로저
    let onConfirm: (() -> Void)?
    let onCancel: (() -> Void)?
    let onDismiss: (() -> Void)?
    let onSecondary: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)
            
            if isPresented {
                Color.gray900.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(1)
                    .transition(.opacity)
                    .onTapGesture {
                        guard isProcessing == false else { return }
                        if let onDismiss {
                            onDismiss()
                        } else if let onCancel {
                            onCancel()
                        } else {
                            isPresented.toggle()
                        }
                    }
                
                NekiAlertModal(hasIcon: hasIcon) {
                    alertContent
                } actions: {
                    buttonStack
                }
                .padding(.horizontal, 28)
                .zIndex(2)
                .transition(.scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.7)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }

    @ViewBuilder
    private var alertContent: some View {
        switch contentStyle {
        case .standard:
            VStack(spacing: 4) {
                titleText
                    .nekiFont(.title18Bold)

                subtitleText
            }

        case let .marketingConsent(description):
            VStack(spacing: 2) {
                titleText
                    .nekiFont(.title24SemiBold)

                subtitleText
                    .padding(.top, 4)

                description
                    .nekiFont(.caption12Regular)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.gray50)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.gray100, lineWidth: 1)
                    }
                    .padding(.top, 20)
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .foregroundStyle(.gray900)
            .multilineTextAlignment(.center)
    }

    private var subtitleText: some View {
        Text(subtitle)
            .nekiFont(.body14Regular)
            .foregroundStyle(.gray500)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Button Logic
    @ViewBuilder
    private var buttonStack: some View {
        switch style {
        case .plain:
            confirmButton
            
        case .cancelable:
            HStack(spacing: 10) {
                cancelButton
                confirmButton
            }
            
        case .primarySecondary:
            VStack(spacing: 4) {
                confirmButton
                secondaryButton
            }
        }
    }
    
    // 개별 버튼 컴포넌트
    private var confirmButton: some View {
        Button {
            onConfirm?()
        } label: {
            Text(confirmText)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.nekiCTA(.primary))
        .disabled(isProcessing)
    }
    
    private var cancelButton: some View {
        Button {
            onCancel?()
        } label: {
            Text(cancelText ?? "취소")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.nekiCTA(.secondary))
        .disabled(isProcessing)
    }
    
    private var secondaryButton: some View {
        Button {
            onSecondary?()
        } label: {
            Text(secondaryText ?? "선택")
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 4)
                .underline()
                .tint(.primary500)
                .nekiFont(.body14Regular)
        }
        .disabled(isProcessing)
    }
}

// MARK: - View Extension (Public Interface)

public extension View {
    func nekiAlert(
        isPresented: Binding<Bool>,
        style: NekiAlertStyle = .plain,
        contentStyle: NekiAlertContentStyle = .standard,
        title: String,
        subtitle: String,
        confirmText: String = "확인",
        cancelText: String? = nil,
        secondaryText: String? = nil,
        isProcessing: Bool = false,
        hasIcon: Bool = true,
        onConfirm: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onSecondary: (() -> Void)? = nil
    ) -> some View {
        self.modifier(NekiAlertModifier(
            isPresented: isPresented,
            style: style,
            contentStyle: contentStyle,
            title: title,
            subtitle: subtitle,
            confirmText: confirmText,
            cancelText: cancelText,
            secondaryText: secondaryText,
            isProcessing: isProcessing,
            hasIcon: hasIcon,
            onConfirm: onConfirm,
            onCancel: onCancel,
            onDismiss: onDismiss,
            onSecondary: onSecondary
        ))
    }
}
