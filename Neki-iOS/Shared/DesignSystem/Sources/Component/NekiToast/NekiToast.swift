//
//  NekiToast.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/3/26.
//

import SwiftUI

public enum NekiToastStyle {
    case success
    case error
    case info
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success: return .primary500
        case .error: return .red
        case .info: return .primary500
        }
    }
}

public struct NekiToastItem: Equatable {
    public typealias Interaction = () -> Void
    
    let id: UUID = UUID()
    let message: String
    let style: NekiToastStyle
    let duration: Double
    let buttonTitle: String?
    let action: Interaction?
    
    public init(
        _ message: String,
        style: NekiToastStyle = .info,
        duration: Double = 3.0,
        buttonTitle: String? = nil,
        action: Interaction? = nil
    ) {
        self.message = message
        self.style = style
        self.duration = duration
        self.buttonTitle = buttonTitle
        self.action = action
    }
    
    public static func == (lhs: NekiToastItem, rhs: NekiToastItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.message == rhs.message &&
        lhs.style == rhs.style &&
        lhs.buttonTitle == rhs.buttonTitle
    }
}

struct NekiToastView: View {
    let item: NekiToastItem
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: item.style.iconName)
                .foregroundStyle(item.style.iconColor)
            
            Text(item.message)
                .nekiFont(.body16SemiBold)
                .foregroundStyle(.white)
                .lineLimit(2)
            
            Spacer()
            
            if let buttonTitle = item.buttonTitle, let action = item.action {
                Button {
                    action()
                    onDismiss()
                } label: {
                    Text(buttonTitle)
                        .nekiFont(.body14Medium)
                        .foregroundStyle(.gray25)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.gray700)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(.gray800)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct NekiToastModifier: ViewModifier {
    @Binding var item: NekiToastItem?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let currentItem = item {
                    nekiToastView(currentItem)
                }
            }
    }
    
    private func nekiToastView(_ item: NekiToastItem) -> some View {
        NekiToastView(item: item) { withAnimation { self.item = nil } }
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1000)
            .task(id: item.id) {
                try? await Task.sleep(for: .seconds(item.duration))
                withAnimation { self.item = nil }
            }
    }
}


// MARK: - NekiToast + Accessor

public extension View {
    func nekiToast(item: Binding<NekiToastItem?>) -> some View {
        modifier(NekiToastModifier(item: item))
    }
}
