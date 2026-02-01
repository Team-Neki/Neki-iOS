//
//  PoseDetailView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher
import os

struct PoseDetailView: View {
    @Bindable var store: StoreOf<PoseDetailFeature>
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $store.selectedID.sending(\.pageChanged)) {
                ForEach(store.items) { item in
                    KFImage(item.imageURL)
                        .resizable()
                        .placeholder {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .retry(maxCount: 3, interval: .seconds(5))
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    Button {
                        store.send(.onTapScrap)
                    } label: {
                        Image(store.isScrapped ? .iconBookmarkFill : .iconBookmark)
                    }
                }
                .padding()
            }
            .frame(height: 68)
            .background(.white)
        }
        .nekiToolbar(
            left: { NekiToolBar.back { store.send(.didTapBackButton) } },
            center: { NekiToolBar.textCenter("포즈 상세") }
        )
        .background(.white)
    }
}
