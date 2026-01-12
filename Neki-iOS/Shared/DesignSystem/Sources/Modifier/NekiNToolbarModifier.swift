//
//  NekiNToolbarModifier.swift
//  Neki-iOS
//
//  Created by OneTen on 1/11/26.
//

import SwiftUI

struct NekiNToolbarModifier: ViewModifier {
    let toolbar: NekiToolBar
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

extension View {
    /// custom toolbar를 추가합니다.
    /// - Parameters:
    ///    - isOverlay: true면 컨텐츠 위에 뜹니다(Overlay). false면 컨텐츠를 밀어냅니다(Inset). (기본값: false)
    public func nekiToolbar(
        left: NekiToolBar.LeftItem = .none,
        center: NekiToolBar.CenterItem = .none,
        right: NekiToolBar.RightItem = .none,
        backgroundColor: Color? = nil,
        isOverlay: Bool = false
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .modifier(
                NekiNToolbarModifier(
                    toolbar: NekiToolBar(
                        leftItem: left,
                        centerItem: center,
                        rightItem: right,
                        backgroundColor: backgroundColor ?? (isOverlay ? .clear : .white)
                    ),
                    isOverlay: isOverlay
                )
            )
    }
}
