//
//  NekiToastModifier.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/5/26.
//

import SwiftUI

struct NekiToastModifier: ViewModifier {
    @Binding var item: NekiToastItem?
    @State private var presentedItem: NekiToastItem?
    @State private var presentationTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let currentItem = presentedItem {
                    nekiToastView(currentItem)
                }
            }
            .onChange(of: item) { _, newItem in
                presentLatestToast(newItem)
            }
            .onAppear {
                presentLatestToast(item)
            }
            .onDisappear {
                presentationTask?.cancel()
                presentationTask = nil
                presentedItem = nil
            }
    }
    
    private func nekiToastView(_ item: NekiToastItem) -> some View {
        NekiToastView(item: item) { dismiss(itemID: item.id) }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
            .id(item.id)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1000)
            .task(id: item.id) {
                do {
                    try await Task.sleep(for: .seconds(item.duration))
                } catch { return }
                dismiss(itemID: item.id)
            }
    }

    private func presentLatestToast(_ newItem: NekiToastItem?) {
        presentationTask?.cancel()

        guard let newItem else {
            withAnimation { presentedItem = nil }
            presentationTask = nil
            return
        }

        presentationTask = Task { @MainActor in
            withAnimation { presentedItem = nil }
            await Task.yield()
            guard Task.isCancelled == false else { return }
            withAnimation { presentedItem = newItem }
            if item?.id == newItem.id { presentationTask = nil }
        }
    }

    private func dismiss(itemID: NekiToastItem.ID) {
        guard presentedItem?.id == itemID else { return }
        withAnimation {
            presentedItem = nil
            if item?.id == itemID { item = nil }
        }
    }
}


// MARK: - NekiToast + Accessor

public extension View {
    func nekiToast(item: Binding<NekiToastItem?>) -> some View {
        modifier(NekiToastModifier(item: item))
    }
}
