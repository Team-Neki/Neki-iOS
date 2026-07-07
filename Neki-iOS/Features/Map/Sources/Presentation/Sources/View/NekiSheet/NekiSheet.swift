//
//  NekiSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/28/25.
//

import SwiftUI

public struct NekiSheet<Content: View, Controllers: View>: View {
    @Environment(\.sheetConfiguration) private var configuration
    @Binding var selection: NekiSheetDetent
    @State private var translation: CGFloat = .zero
    @State private var isContentScrollAtTop: Bool = true
    @State private var isDraggingSheet: Bool = false
    @State private var controllerHeight: CGFloat = .zero
    
    let controllers: () -> Controllers
    let content: () -> Content
    
    private let defaultSpacing: CGFloat = 20
    
    var isControllersVisible: Bool { selection == MapFeature.SheetStage.first.detent || selection == MapFeature.SheetStage.second.detent }
    
    public var body: some View {
        GeometryReader { proxy in
            let layout = layout(in: proxy.size.height)
            
            VStack(spacing: defaultSpacing) {
                if isControllersVisible {
                    controllers()
                        .measureHeight { controllerHeight = $0 }
                }
                
                VStack(spacing: .zero) {
                    indicator
                    content()
                        .environment(\.nekiSheetScrollStateHandler, .init { isAtTop in
                            guard isContentScrollAtTop != isAtTop else { return }
                            isContentScrollAtTop = isAtTop
                        })
                }
                .background(configuration.backgroundColor)
                .clipShape(PresentationCornerShape(radius: configuration.cornerRadius, corners: [.topLeft, .topRight]))
            }
            .frame(width: proxy.size.width, height: layout.maxHeight)
            .shadow(
                color: selection == .hidden ? .clear : configuration.shadowColor,
                radius: selection == .hidden ? .zero : configuration.shadowRadius
            )
            .padding(.bottom, selection == .hidden ? 0 : configuration.bottomInset)
            .frame(height: proxy.size.height, alignment: .bottom)
            .offset(y: max(.zero, layout.dragOffset - (isControllersVisible ? (controllerHeight + defaultSpacing) : .zero)))
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value, layout: layout, proxyHeight: proxy.size.height)
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
        VStack {
            RoundedRectangle(cornerRadius: configuration.indicatorSize.height / 2)
                .fill(configuration.indicatorColor)
                .frame(width: configuration.indicatorSize.width, height: configuration.indicatorSize.height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        .contentShape(.rect)
        .onTapGesture { withAnimation(configuration.animation) { selection = .large } }
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

    func shouldHandleSheetDrag(_ value: DragGesture.Value) -> Bool {
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)
        guard verticalDistance > horizontalDistance else { return false }
        guard selection == .large else { return true }
        return value.translation.height > .zero && isContentScrollAtTop
    }

    func handleDragChanged(_ value: DragGesture.Value) {
        guard shouldHandleSheetDrag(value) else {
            isDraggingSheet = false
            translation = .zero
            return
        }

        isDraggingSheet = true
        translation = value.translation.height
    }

    func handleDragEnded(
        _ value: DragGesture.Value,
        layout: SheetLayout,
        proxyHeight: CGFloat
    ) {
        guard isDraggingSheet else {
            translation = .zero
            return
        }

        let inset = configuration.bottomInset
        let predictedHeight = layout.currentHeight - value.translation.height
        let interactiveDetents = configuration.detents.filter { $0 != .hidden }
        let interactiveHeights = interactiveDetents.map { $0.resolve(in: proxyHeight, inset: inset) }
        let closestHeight = interactiveHeights.min(by: { abs($0 - predictedHeight) < abs($1 - predictedHeight) }) ?? layout.currentHeight

        guard let newDetent = interactiveDetents.first(where: { abs($0.resolve(in: proxyHeight, inset: inset) - closestHeight) < 1.0 }) else {
            return resetDragState()
        }

        withAnimation(configuration.animation) {
            selection = newDetent
            translation = .zero
            isDraggingSheet = false
        }
    }

    func resetDragState() {
        withAnimation(configuration.animation) {
            translation = .zero
            isDraggingSheet = false
        }
    }
}


// MARK: - NekiSheet + Accessor

public extension View {
    /// 뷰 계층에 NekiSheet를 추가합니다.
    ///
    /// - Parameters:
    ///     - selection: 시트 높이 상태 바인딩
    ///     - content: 시트 내부 컨텐츠
    func nekiSheet<Content: View, Controllers: View>(
        selection: Binding<NekiSheetDetent>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder controllers: @escaping () -> Controllers
    ) -> some View {
        ZStack {
            self
            NekiSheet(selection: selection, controllers: controllers, content: content)
        }
    }
    
    /// 시트 하단에 여백을 추가합니다.
    ///
    /// - Parameter height: 띄울 높이 (기본값: 현재 디바이스의 탭바 높이)
    func nekiSheetBottomInset(_ height: CGFloat = .screenTabBarHeight) -> some View {
        transformEnvironment(\.sheetConfiguration) { $0.bottomInset = height }
    }
    
    /// 뷰 영역의 높이를 확인합니다.
    func measureHeight(perform action: @escaping (CGFloat) -> Void) -> some View {
        self.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { action(proxy.size.height) }
                    .onChange(of: proxy.size.height) { _, newValue in
                        action(newValue)
                    }
            }
        )
    }
}


// MARK: - NekiSheetScrollStateHandler

struct NekiSheetScrollStateHandler {
    var updateIsAtTop: (Bool) -> Void

    init(updateIsAtTop: @escaping (Bool) -> Void = { _ in }) {
        self.updateIsAtTop = updateIsAtTop
    }
}

private struct NekiSheetScrollStateHandlerKey: EnvironmentKey {
    static let defaultValue = NekiSheetScrollStateHandler()
}

extension EnvironmentValues {
    var nekiSheetScrollStateHandler: NekiSheetScrollStateHandler {
        get { self[NekiSheetScrollStateHandlerKey.self] }
        set { self[NekiSheetScrollStateHandlerKey.self] = newValue }
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
        return 40 + (window?.safeAreaInsets.bottom ?? 0)
    }
}
