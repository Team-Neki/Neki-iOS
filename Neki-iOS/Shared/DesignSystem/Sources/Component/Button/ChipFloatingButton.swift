//
//  ChipFloatingButton.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/3/26.
//

import SwiftUI

public struct ChipFloatingButton: View {
    public enum Style { case map, randomPose }
    
    private let icon: Image
    private let title: Text
    private let action: () -> Void
    
    public init(_ style: Style, action: @escaping () -> Void) {
        switch style {
        case .map:
            icon = Image(.iconPin)
            title = Text("지도로")
        case .randomPose:
            icon = Image(.iconRepeat)
            title = Text("랜덤포즈 추천")
        }
        self.action = action
    }
    
    public var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                icon
                title
            }
            .padding(.horizontal, 12)
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
