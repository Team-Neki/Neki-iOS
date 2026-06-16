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
    
    var iconName: UIImage {
        switch self {
        case .success: return .iconCheck
        case .error: return .iconError
        case .info: return .iconInfo
        }
    }
}

public struct NekiToastItem: Identifiable, Equatable {
    public static func == (lhs: NekiToastItem, rhs: NekiToastItem) -> Bool {
        lhs.id == rhs.id
    }
    
    public typealias Interaction = () -> Void
    
    public let id: UUID = UUID()
    let message: String
    let style: NekiToastStyle
    let duration: Double
    let buttonTitle: String?
    let action: Interaction?
    
    public init(
        _ message: String,
        style: NekiToastStyle = .info,
        duration: Double = 1.8,
        buttonTitle: String? = nil,
        action: Interaction? = nil
    ) {
        self.message = message
        self.style = style
        self.duration = duration
        self.buttonTitle = buttonTitle
        self.action = action
    }
}

struct NekiToastView: View {
    let item: NekiToastItem
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(uiImage: item.style.iconName)
                .padding(.trailing, 8)
            
            Text(item.message)
                .nekiFont(.body16Medium)
                .foregroundStyle(.white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
        .frame(width: 303)
        .padding(16)
        .background(.gray800)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
