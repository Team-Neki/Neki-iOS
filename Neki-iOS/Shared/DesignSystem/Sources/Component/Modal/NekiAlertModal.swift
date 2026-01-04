//
//  NekiAlertModal.swift
//  Neki-iOS
//
//  Created by OneTen on 1/4/26.
//

import SwiftUI

public struct NekiAlertModal: View {
    
    public enum AlertStyle {
        case plain
        case cancelable
    }
    
    // MARK: - Property Wrappers
    
    @State private var isProcessing: Bool = false
    
    // MARK: - Properties
    
    let style: AlertStyle
    let onConfirm: () async -> Void
    let onCancel: () -> Void
    let titleMessage: String
    let subTitleMessage: String
    let confirmText: String
    var cancelText: String? = nil
    
    //MARK: - init
    
    public init(
        style: AlertStyle,
        onConfirm: @escaping () async -> Void,
        onCancel: @escaping () -> Void = {},
        titleMessage: String,
        subTitleMessage: String,
        confirmText: String,
        cancelText: String? = nil
    ) {
        self.style = style
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.titleMessage = titleMessage
        self.subTitleMessage = subTitleMessage
        self.confirmText = confirmText
        self.cancelText = cancelText
    }
    
    // MARK: - Main Body
    
    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            
            Image(.iconCircleAlertFill)
                .padding(.top, 20)
            
            Text(titleMessage)
                .nekiFont(.title18Bold)
                .foregroundStyle(.gray900)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            
            Text(subTitleMessage)
                .nekiFont(.body14Regular)
                .foregroundStyle(.gray500)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            
            Group {
                if style == .cancelable {
                    HStack(alignment: .center, spacing: 10) {
                        cancelButton
                        confirmButton
                    }
                } else {
                    confirmButton
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
            .padding(.horizontal, 12)
            
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}


// MARK: - Sub Views

extension NekiAlertModal {
    private var cancelButton: some View {
        Button {
            onCancel()
        } label: {
            Text(cancelText ?? "취소")
        }
        .buttonStyle(.nekiCTA(.secondary))
        .disabled(isProcessing)
    }
    
    private var confirmButton: some View {
        Button {
            confirmOnce()
        } label: {
            Text(confirmText)
        }
        .buttonStyle(.nekiCTA(.primary))
        .disabled(isProcessing)
    }
}

// MARK: - Private Func

extension NekiAlertModal {
    private func confirmOnce() {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task {
            await onConfirm()
            isProcessing = false
        }
    }
}
