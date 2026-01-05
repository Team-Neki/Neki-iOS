//
//  NekiTooltipModifier.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/5/26.
//

import SwiftUI

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

