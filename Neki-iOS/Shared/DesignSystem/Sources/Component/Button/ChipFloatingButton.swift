//
//  ChipFloatingButton.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/3/26.
//

import SwiftUI

public struct ChipFloatingButton: View {
    public enum Style {
        case map, randomPose
        
        var icon: ImageResource {
            switch self {
            case .map: return .iconPin
            case .randomPose: return .iconRepeat
            }
        }
        
        var title: String {
            switch self {
            case .map: return "지도로"
            case .randomPose: return "랜덤 포즈 추천"
            }
        }
    }
    
    private let icon: Image
    private let title: Text
    private let action: () -> Void
    
    public init(_ style: Style, action: @escaping () -> Void) {
        self.icon = Image(style.icon)
        self.title = Text(style.title)
        self.action = action
    }
    
    public var body: some View {
        Button {
            action()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                icon
                title
            }
            .frame(height: 28)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .nekiFont(.title18SemiBold)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 999)
                    .fill(.gray800)
            )
        }
    }
}
