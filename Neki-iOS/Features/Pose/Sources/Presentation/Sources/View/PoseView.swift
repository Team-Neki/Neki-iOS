//
//  PoseView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture

struct PoseView: View {
    
    let store: StoreOf<PoseFeature>
    
    var body: some View {
        ScrollView {
            MasonryGridView(
                items: Array(store.items),
                columns: 2
            ) { item in
                FeedImageView(item: item)
                    .onTapGesture {
                        store.send(.imageTapped(item))
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 128)
        }
        .scrollIndicators(.never)
        .task {
            await store.send(.onAppear).finish()
        }
    }
}
