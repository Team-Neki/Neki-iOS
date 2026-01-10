//
//  NekiSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/28/25.
//

import SwiftUI

public struct NekiSheet<Content: View>: View {
    @Environment(\.sheetConfiguration) private var configuration
    @Binding var selection: NekiSheetDetent
    @State private var translation: CGFloat = .zero
    @State private var scrollOffset: CGFloat = .zero
    
    let content: () -> Content
    
    public var body: some View {
        GeometryReader { proxy in
            let layout = layout(in: proxy.size.height)
            
            VStack(spacing: .zero) {
                indicator
                
                content()
            }
            .frame(width: proxy.size.width, height: layout.maxHeight)
            .background(configuration.backgroundColor)
            .clipShape(PresentationCornerShape(radius: configuration.cornerRadius, corners: [.topLeft, .topRight]))
            .shadow(
                color: selection == .hidden ? .clear : configuration.shadowColor,
                radius: selection == .hidden ? .zero : configuration.shadowRadius
            )
            .padding(.bottom, selection == .hidden ? 0 : configuration.bottomInset)
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
                        let inset = configuration.bottomInset
                        let predictedHeight = layout.currentHeight - value.translation.height
                        let interactiveDetents = configuration.detents.filter { $0 != .hidden }
                        let interactiveHeights = interactiveDetents.map { $0.resolve(in: proxy.size.height, inset: inset) }
                        let closestHeight = interactiveHeights.min(by: { abs($0 - predictedHeight) < abs($1 - predictedHeight) }) ?? layout.currentHeight
                        
                        guard let newDetent = interactiveDetents.first(where: { abs($0.resolve(in: proxy.size.height, inset: inset) - closestHeight) < 1.0 }) else {
                            return withAnimation(configuration.animation) { translation = .zero }
                        }
                        
                        withAnimation(configuration.animation) {
                            selection = newDetent
                            translation = .zero
                        }
                    }
            )
            .allowsHitTesting(selection != .hidden)
        }
        .ignoresSafeArea(.container, edges: .bottom)
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
        let inset = configuration.bottomInset
        let sortedHeights = configuration.detents.map { $0.resolve(in: totalHeight, inset: inset) }.sorted()
        let targetHeight = selection.resolve(in: totalHeight, inset: inset)
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


// MARK: - NekiSheet + Accessor

public extension View {
    /// 뷰 계층에 NekiSheet를 추가합니다.
    ///
    /// - Parameters:
    ///     - selection: 시트 높이 상태 바인딩
    ///     - content: 시트 내부 컨텐츠
    func nekiSheet<Content: View>(
        selection: Binding<NekiSheetDetent>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            NekiSheet(selection: selection, content: content)
        }
    }
    
    /// 시트 하단에 여백을 추가합니다.
    ///
    /// - Parameter height: 띄울 높이 (기본값: 현재 디바이스의 탭바 높이)
    func nekiSheetBottomInset(_ height: CGFloat = .screenTabBarHeight) -> some View {
        transformEnvironment(\.sheetConfiguration) { $0.bottomInset = height }
    }
}


// MARK: - CGFloat + TabBar Height

public extension CGFloat {
    /// 현재 디바이스 기준 탭바의 총 높이 (표준 높이 49 + 하단 Safe Area)
    static var screenTabBarHeight: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        
        // 탭바 순수 높이(49) + 하단 Safe Area
        return 49 + (window?.safeAreaInsets.bottom ?? 0)
    }
}
