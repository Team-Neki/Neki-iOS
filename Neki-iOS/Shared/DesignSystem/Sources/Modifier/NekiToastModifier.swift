//
//  NekiToastModifier.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/5/26.
//

import SwiftUI

struct NekiToastModifier: ViewModifier {
    @Binding var item: NekiToastItem?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let currentItem = item {
                    nekiToastView(currentItem)
                }
            }
    }
    
    private func nekiToastView(_ item: NekiToastItem) -> some View {
        NekiToastView(item: item) { withAnimation { self.item = nil } }
            .padding(.horizontal, 20)
            .id(item.id)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1000)
            .task(id: item.id) {
                do {
                    try await Task.sleep(for: .seconds(item.duration))
                } catch { }
                withAnimation { self.item = nil }
            }
    }
}


// MARK: - NekiToast + Accessor

public extension View {
    func nekiToast(item: Binding<NekiToastItem?>) -> some View {
        modifier(NekiToastModifier(item: item))
    }
}
