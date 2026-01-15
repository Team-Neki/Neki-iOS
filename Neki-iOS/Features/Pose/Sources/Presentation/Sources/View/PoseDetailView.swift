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
        VStack(alignment: .center, spacing: 0) {
            KFImage(store.item.imageURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .retry(maxCount: 3, interval: .seconds(5))
                .onFailure { error in
                    Logger.presentation.error("이미지 로드 실패: \(error)")
                    Logger.presentation.error("실패한 이미지 id: \(store.item.id)")
                }
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
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
        }
        .nekiToolbar(left: .back(action: {store.send(.didTapBackButton)}), center: .text("포즈 상세"))
        .background(.white)
    }
}
