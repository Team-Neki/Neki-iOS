//
//  NekiImagePicker.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import SwiftUI
import ComposableArchitecture
import PhotosUI

public struct NekiImagePicker<Label: View>: View {
    @Bindable var store: StoreOf<ImagePickerFeature>
    let label: () -> Label
    
    public init(
        store: StoreOf<ImagePickerFeature>,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.store = store
        self.label = label
    }
    
    public var body: some View {
        PhotosPicker(
            selection: $store.pickerItems.sending(\.pickerItemsChanged),
            maxSelectionCount: store.remainingCount,
            matching: .images
        ) {
            label()
        }
        .disabled(store.remainingCount <= 0 || store.isLoading)
    }
}
