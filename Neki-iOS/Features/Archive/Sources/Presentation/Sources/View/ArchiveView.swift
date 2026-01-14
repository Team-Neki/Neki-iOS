//
//  ArchiveView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveView: View {
    
    let store: StoreOf<ArchiveFeature>
    
    var body: some View {
        ScrollView {
            MasonryGridView(
                items: Array(store.items),
                columns: 2
            ) { item in
                ArchiveImageView(item: item)
                    .onTapGesture {
                        store.send(.imageTapped(item))
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 128)
        }
        .scrollIndicators(.never)
        .onAppear {
            store.send(.onAppear)
        }
    }
}
