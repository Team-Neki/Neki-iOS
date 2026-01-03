//
//  FloatingButton.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/3/26.
//

import SwiftUI

struct MenuFloaterModifier<Menu: View>: ViewModifier {
    @State private var isMenuShowing: Bool = false
    
    private let menuContent: () -> Menu
    private let menuTransitionScale: CGFloat = 0.8
    private let buttonPadding: CGFloat = 13
    private let containerPadding: CGFloat = 20
    private let shadowOpacity: Double = 0.2
    private let shadowRadius: CGFloat = 6
    private let shadowPositionX: CGFloat = .zero
    private let shadowPositionY: CGFloat = 4
    
    init(@ViewBuilder menu: @escaping () -> Menu) { menuContent = menu }
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
            
            VStack(alignment: .trailing, spacing: 12) {
                if isMenuShowing { menu }
                floatingButton
            }
            .padding(containerPadding)
        }
    }
    
    private var menu: some View {
        menuContent()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.scale(scale: menuTransitionScale, anchor: .bottomTrailing).combined(with: .opacity))
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: shadowPositionX, y: shadowPositionY)
    }
    
    private var floatingButton: some View {
        Button {
            withAnimation { isMenuShowing.toggle() }
        } label: {
            Image(isMenuShowing ? .iconPlusWhite : .iconXmarkWhite)
                .padding(buttonPadding)
                .background(
                    Circle()
                        .fill(isMenuShowing ? .primary400 : .gray700)
                        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: shadowPositionX, y: shadowPositionY)
                )
        }
    }
}


// MARK: - MenuFloaterModifier + Accessor

public extension View {
    func menuFloater<Menu: View>(@ViewBuilder menu: @escaping () -> Menu) -> some View {
        modifier(MenuFloaterModifier(menu: menu))
    }
}
