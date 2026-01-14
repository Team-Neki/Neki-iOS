//
//  PoseDetailView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct PoseDetailView: View {
    let store: StoreOf<PoseDetailFeature>
    
    var body: some View {
        VStack {
            KFImage(store.item.imageURL)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            
            Text("이미지 ID: \(store.item.id)")
                .font(.headline)
            
            Button("더 자세히 보기 (Next)") {
                store.send(.didTapDeepLinkButton(store.item))
            }
            
            Spacer()
        }
        .navigationTitle("상세 보기")
        .navigationBarTitleDisplayMode(.inline)
    }
}
