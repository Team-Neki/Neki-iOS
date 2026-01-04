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
        case .dark: return .gray700
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
        .fixedSize()
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
    
    private var contentArea: some View {
        HStack(spacing: 2) {
            Text(text)
                .nekiFont(.body14Medium)
                .foregroundStyle(style.foregroundColor)
                .multilineTextAlignment(.center)
            
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

struct NekiTooltipModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var tooltipSize: CGSize = .zero
    @State private var targetFrame: CGRect = .zero
    
    let text: String
    let style: NekiTooltipStyle
    let position: NekiTooltipPosition
    let showDismissButton: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { targetFrame = proxy.frame(in: .global) }
                        .onChange(of: proxy.frame(in: .global)) { _, newValue in
                            targetFrame = newValue
                        }
                }
            )
            .overlay(alignment: position.overlayAlignment) {
                if isPresented { tooltipArea }
            }
    }
    
    private var tooltipArea: some View {
        let offsets = calculateOffsets()
        
        return NekiTooltipView(
            text: text,
            style: style,
            position: position,
            arrowOffset: offsets.arrowX,
            onDismiss: showDismissButton ? { withAnimation { isPresented = false } } : nil
        )
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { tooltipSize in
            self.tooltipSize = tooltipSize
        }
        .offset(x: offsets.tooltipX, y: offsets.tooltipY)
        .transition(.scale(scale: 0.8, anchor: position == .top ? .bottom : .top).combined(with: .opacity))
    }
    
    private func calculateOffsets() -> (tooltipX: CGFloat, tooltipY: CGFloat, arrowX: CGFloat) {
        guard tooltipSize != .zero, targetFrame != .zero else { return (.zero, .zero, .zero) }
        let yOffset: CGFloat = position == .top ? -tooltipSize.height : tooltipSize.height
        let screenWidth = UIScreen.main.bounds.width
        let safeAreaPadding: CGFloat = 16
        let targetCenterX = targetFrame.midX
        let tooltipHalfWidth = tooltipSize.width / 2
        let expectedLeft = targetCenterX - tooltipHalfWidth
        let expectedRight = targetCenterX + tooltipHalfWidth
        
        var shiftX: CGFloat = .zero
        if expectedLeft < safeAreaPadding {
            shiftX = safeAreaPadding - expectedLeft
        } else if expectedRight > (screenWidth - safeAreaPadding) {
            shiftX = (screenWidth - safeAreaPadding) - expectedRight
        }
        
        let maxArrowOffset = tooltipHalfWidth - 16
        let arrowX = -shiftX
        let clampedArrowX = min(max(arrowX, -maxArrowOffset), maxArrowOffset)
        return (shiftX, yOffset, clampedArrowX)
    }
}


// MARK: - NekiTooltip + Accessor

public extension View {
    func nekiTooltip(
        isPresented: Binding<Bool>,
        _ text: String,
        position: NekiTooltipPosition = .bottom,
        style: NekiTooltipStyle = .dark,
        showDismiss: Bool = false
    ) -> some View {
        modifier(NekiTooltipModifier(isPresented: isPresented, text: text, style: style, position: position, showDismissButton: showDismiss))
    }
}
