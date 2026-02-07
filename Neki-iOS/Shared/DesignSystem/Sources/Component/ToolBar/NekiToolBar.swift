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
        Items.Title(title: title, action: action)
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
            }
        }
        
        struct Close: View {
            let action: () -> Void
            var body: some View {
                Button(action: action) { Image(.iconXmarkBlack) }
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
            }
        }
    }
}

public struct NekiToolbarLayout<Left: View, Center: View, Right: View>: View {
    let left: Left
    let center: Center
    let right: Right
    let backgroundColor: Color
    
    public init(
        backgroundColor: Color = .white,
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) {
        self.backgroundColor = backgroundColor
        self.left = left()
        self.center = center()
        self.right = right()
    }
    
    public var body: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center, spacing: 0) {
                left
                Spacer()
                right
            }
            .padding(.horizontal, 20)
            .frame(height: 54)
            
            center
        }
        .background(backgroundColor)
        .frame(height: 54)
    }
}
