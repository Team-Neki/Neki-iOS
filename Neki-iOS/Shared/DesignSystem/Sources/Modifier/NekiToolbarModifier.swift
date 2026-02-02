//
//  NekiToolbarModifier.swift
//  Neki-iOS
//
//  Created by OneTen on 1/11/26.
//

import SwiftUI

struct NekiToolbarModifier<ToolbarContent: View>: ViewModifier {
    let toolbar: ToolbarContent
    let isOverlay: Bool
    
    func body(content: Content) -> some View {
        if isOverlay {
            content
                .overlay(alignment: .top) {
                    toolbar
                        .zIndex(9)
                }
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    toolbar
                }
        }
    }
}


// MARK: - Accessors

public extension View {
    func nekiToolbar<L: View, C: View, R: View>(
        backgroundColor: Color? = nil,
        isOverlay: Bool = false,
        @ViewBuilder left: () -> L = { EmptyView() },
        @ViewBuilder center: () -> C = { EmptyView() },
        @ViewBuilder right: () -> R = { EmptyView() }
    ) -> some View {
        let toolbar = NekiToolbarLayout(
            backgroundColor: backgroundColor ?? (isOverlay ? .clear : .white),
            left: left,
            center: center,
            right: right
        )
        return self
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .modifier(NekiToolbarModifier(toolbar: toolbar, isOverlay: isOverlay))
    }
}
