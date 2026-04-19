//
//  NekiToolBar.swift
//  Neki-iOS
//
//  Created by OneTen on 1/10/26.
//

import SwiftUI

public enum NekiToolBar {
    public static func back(action: @escaping () -> Void) -> some View {
        Items.Back(action: action)
    }
    
    public static func close(action: @escaping () -> Void) -> some View {
        Items.Close(action: action)
    }
    
    public static func textLeft(_ title: String, action: (() -> Void)? = nil) -> some View {
        Items.Title(title: title, action: action).padding(.leading, 12)
    }
    
    public static func textCenter(_ title: String, action: (() -> Void)? = nil) -> some View {
        Items.Title(title: title, action: action)
    }
    
    /// 우측 텍스트 버튼 (활성화/비활성화 상태 지원)
    public static func textRight(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Items.TextButton(title: title, isEnabled: isEnabled, action: action)
    }
    
    public static func icon(_ image: UIImage, action: (() -> Void)? = nil) -> some View {
        Items.Icon(image: image, action: action)
    }
    
    public static func items<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            content()
        }
    }
}


// MARK: - Subviews

extension NekiToolBar {
    enum Items {
        struct Back: View {
            let action: () -> Void
            var body: some View {
                Button(action: action) { Image(.iconChevronLeft) }
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
        }
        
        struct Close: View {
            let action: () -> Void
            var body: some View {
                Button(action: action) { Image(.iconXmarkBlack) }
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
        }
        
        struct Title: View {
            let title: String
            let action: (() -> Void)?
            
            var body: some View {
                if let action = action {
                    Button(action: action) { content }
                } else {
                    content
                }
            }
            
            var content: some View {
                Text(title)
                    .nekiFont(.title20SemiBold)
                    .foregroundStyle(.gray900)
            }
        }
        
        struct TextButton: View {
            let title: String
            let isEnabled: Bool
            let action: () -> Void
            
            var body: some View {
                Button(action: action) {
                    Text(title)
                        .nekiFont(.body16SemiBold)
                        .foregroundStyle(isEnabled ? .primary500 : .gray400)
                }
                .disabled(!isEnabled)
            }
        }
        
        struct Icon: View {
            let image: UIImage
            let action: (() -> Void)?
            
            var body: some View {
                Button {
                    action?()
                } label: {
                    Image(uiImage: image)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
        }
    }
}

public struct NekiToolbarContent<Left: View, Center: View, Right: View>: ToolbarContent {
    let left: Left
    let center: Center
    let right: Right
    
    public init(
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) {
        self.left = left()
        self.center = center()
        self.right = right()
    }
    
    public var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            left
                .offset(x: -8)
        }
        ToolbarItem(placement: .principal) {
            center
        }
        ToolbarItem(placement: .topBarTrailing) {
            right
                .offset(x: -4)
        }
    }
}

public extension View {
    func nekiToolbar<Left: View, Center: View, Right: View>(
        backgroundColor: Color? = nil,
        isOverlay: Bool = false,
        @ViewBuilder left: () -> Left = { EmptyView() },
        @ViewBuilder center: () -> Center = { EmptyView() },
        @ViewBuilder right: () -> Right = { EmptyView() }
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar { NekiToolbarContent(left: left, center: center, right: right) }
            .toolbarBackground(backgroundColor ?? (isOverlay ? .clear : .white), for: .navigationBar)
            .toolbarBackground(isOverlay ? .hidden : .visible, for: .navigationBar)
            .onAppear {
                let appearance = UINavigationBarAppearance()
                if isOverlay {
                    appearance.configureWithTransparentBackground()
                } else {
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor(backgroundColor ?? .white)
                }
                
                appearance.shadowColor = .clear
                appearance.shadowImage = nil
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }
    }
}

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { viewControllers.count > 1 }
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }
}

