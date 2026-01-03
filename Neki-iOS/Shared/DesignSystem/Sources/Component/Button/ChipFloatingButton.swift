//
//  ChipFloatingButton.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/3/26.
//

import SwiftUI

public struct ChipFloatingButton: View {
    public enum Variant { case map, randomPose }
    
    private let icon: Image
    private let title: Text
    private let action: () -> Void
    
    public init(_ variant: Variant, action: @escaping () -> Void) {
        switch variant {
        case .map:
            icon = Image(.iconPin)
            title = Text("지도로")
        case .randomPose:
            icon = Image(.iconRepeat)
            title = Text("랜덤포즈 추천")
        }
        self.action = action
    }
    
    public init(icon: ImageResource, _ title: String, action: @escaping () -> Void) {
        self.icon = Image(icon)
        self.title =  Text(title)
        self.action = action
    }
    
    public var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: NekiMetric.spacing8) {
                icon
                title
            }
            .padding(.horizontal, NekiMetric.padding12)
            .padding(.vertical, NekiMetric.padding8)
            .nekiFont(.title18SemiBold)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: NekiMetric.radius999)
                    .fill(.gray800)
                    
            )
        }
    }
}
