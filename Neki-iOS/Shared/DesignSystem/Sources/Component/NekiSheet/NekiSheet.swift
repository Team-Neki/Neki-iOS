//
//  NekiSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/28/25.
//

import SwiftUI

public struct NekiSheet<Content: View>: View {
    @Environment(\.sheetConfiguration) private var configuration
    @Binding var selection: Detent
    @State private var translation: CGFloat = .zero
    @State private var scrollOffset: CGFloat = .zero
    
    let content: (Binding<CGFloat>) -> Content
    
    public var body: some View {
        GeometryReader { proxy in
            let layout = layout(in: proxy.size.height)
            
            VStack(spacing: .zero) {
                indicator
                
                content($scrollOffset)
            }
            .frame(width: proxy.size.width, height: layout.maxHeight, alignment: .top)
            .background(configuration.backgroundColor)
            .clipShape(PresentationCornerShape(radius: configuration.cornerRadius, corners: [.topLeft, .topRight]))
            .shadow(color: configuration.shadowColor, radius: configuration.shadowRadius)
            .frame(height: proxy.size.height, alignment: .bottom)
            .offset(y: max(.zero, layout.dragOffset))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let isScrollingUp = scrollOffset > .zero
                        let isDraggingDown = value.translation.height > .zero
                        
                        guard isScrollingUp == false || isDraggingDown == true else { return }
                        translation = value.translation.height
                    }
                    .onEnded { value in
                        let predictedHeight = layout.currentHeight - value.translation.height
                        let closestHeight = layout.sortedHeights.min(by: { abs($0 - predictedHeight) < abs($1 - predictedHeight) }) ?? layout.currentHeight
                        
                        guard let newDetent = configuration.detents.first(where: { $0.resolve(in: proxy.size.height) == closestHeight }) else { return }
                        withAnimation(configuration.animation) {
                            selection = newDetent
                            translation = .zero
                        }
                    }
            )
        }
    }
}


// MARK: - NekiSheet + Subviews

private extension NekiSheet {
    var indicator: some View {
        RoundedRectangle(cornerRadius: configuration.indicatorSize.height / 2)
            .fill(configuration.indicatorColor)
            .frame(width: configuration.indicatorSize.width, height: configuration.indicatorSize.height)
            .padding(.vertical, 10)
    }
}


// MARK: - NekiSheet + Nested Types

private extension NekiSheet {
    struct PresentationCornerShape: Shape {
        var radius: CGFloat
        var corners: UIRectCorner
        
        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: .init(width: radius, height: radius))
            return Path(path.cgPath)
        }
    }
    
    struct SheetLayout {
        let sortedHeights: [CGFloat]
        let maxHeight: CGFloat
        let currentHeight: CGFloat
        let dragOffset: CGFloat
    }
}


// MARK: - NekiSheet + Helper

private extension NekiSheet {
    func layout(in totalHeight: CGFloat) -> SheetLayout {
        let sortedHeights = configuration.detents.map { $0.resolve(in: totalHeight) }.sorted()
        let targetHeight = selection.resolve(in: totalHeight)
        let currentHeight = sortedHeights.min(by: { abs($0 - targetHeight) < abs($1 - targetHeight) }) ?? targetHeight
        let maxHeight = sortedHeights.last ?? totalHeight
        
        let baseOffset = maxHeight - currentHeight
        let dragOffset = baseOffset + translation
        
        return SheetLayout(
            sortedHeights: sortedHeights,
            maxHeight: maxHeight,
            currentHeight: currentHeight,
            dragOffset: dragOffset
        )
    }
}


// MARK: - NekiSheet + ViewModifier

public extension View {
    /// 뷰 계층에 NekiSheet를 추가합니다.
    ///
    /// - Parameters:
    ///     - selection: 시트 높이 상태 바인딩
    ///     - content: 시트 내부 컨텐츠
    func nekiSheet<Content: View>(
        selection: Binding<Detent>,
        @ViewBuilder content: @escaping (Binding<CGFloat>) -> Content
    ) -> some View {
        ZStack {
            self
            NekiSheet(selection: selection, content: content)
        }
    }
    
    func sheetDetents(_ detents: Set<Detent>) -> some View {
        transformEnvironment(\.sheetConfiguration) { $0.detents = detents }
    }
    
    func sheetCornerRadius(_ radius: CGFloat) -> some View {
        transformEnvironment(\.sheetConfiguration) { $0.cornerRadius = radius }
    }
    
    func sheetBackgroundColor(_ color: Color) -> some View {
        transformEnvironment(\.sheetConfiguration) { $0.backgroundColor = color }
    }
}
