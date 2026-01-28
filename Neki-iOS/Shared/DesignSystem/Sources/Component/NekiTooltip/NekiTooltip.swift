//
//  NekiTooltip.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/4/26.
//

import SwiftUI

public enum NekiTooltipStyle {
    case dark, light
    
    var backgroundColor: Color {
        switch self {
        case .dark: return .gray800
        case .light: return .gray25
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .dark: return .white
        case .light: return .gray900
        }
    }
}

public enum NekiTooltipPosition {
    case top, bottom
    
    var overlayAlignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        }
    }
    
    var transitionEdge: Edge {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        }
    }
}

private struct TooltipArrow: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct NekiTooltipView: View {
    private let arrowWidth: CGFloat = 10
    private let arrowHeight: CGFloat = 8
    
    let text: String
    let style: NekiTooltipStyle
    let position: NekiTooltipPosition
    let arrowOffset: CGFloat
    let onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(spacing: .zero) {
            if case .bottom = position {
                arrowArea(pointsUp: true)
            }
            
            contentArea
            
            if case .top = position {
                arrowArea(pointsUp: false)
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .fixedSize()
    }
    
    private var contentArea: some View {
        HStack(spacing: 2) {
            Text(text)
                .nekiFont(.body14Medium)
                .foregroundStyle(style.foregroundColor)
                .multilineTextAlignment(.leading)
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(style == .dark ? .iconXmarkWhite : .iconXmarkBlack)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(style.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func arrowArea(pointsUp: Bool) -> some View {
        TooltipArrow()
            .fill(style.backgroundColor)
            .frame(width: arrowWidth, height: arrowHeight)
            .rotationEffect(pointsUp ? .degrees(0) : .degrees(180))
            .offset(x: arrowOffset)
            .zIndex(1)
    }
}

import ComposableArchitecture
#Preview {
    TabView {
        NaverMapView(store: Store(initialState: MapFeature.State(), reducer: { MapFeature() }))
    }
}
