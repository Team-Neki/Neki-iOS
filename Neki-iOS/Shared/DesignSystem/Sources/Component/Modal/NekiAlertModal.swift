//
//  NekiAlertModal.swift
//  Neki-iOS
//
//  Created by OneTen on 1/4/26.
//

import SwiftUI

public enum NekiAlertStyle {
    case plain
    case cancelable
    case primarySecondary
}

public enum NekiAlertContentStyle {
    case standard
    case marketingConsent(description: Text)
}

/// 알림 모달 위에 보이는 아이콘입니다.
public enum NekiAlertIcon {
    case questionMark
    case bell
    
    var resource: ImageResource {
        switch self {
        case .questionMark:
            .iconQuestionmarkAlert
        case .bell:
            .iconBellAlert
        }
    }
}

public struct NekiAlertModal<Content: View, Actions: View>: View {
    let content: Content
    let actions: Actions
    let hasIcon: Bool
    let icon: NekiAlertIcon
    
    public init(
        hasIcon: Bool,
        icon: NekiAlertIcon = .questionMark,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.hasIcon = hasIcon
        self.icon = icon
        self.content = content()
        self.actions = actions()
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if hasIcon {
                Image(icon.resource)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
            }
            
            content
                .padding(.horizontal, 12)
                .padding(.top, 24)
                .padding(.bottom, 12)
            
            actions
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
