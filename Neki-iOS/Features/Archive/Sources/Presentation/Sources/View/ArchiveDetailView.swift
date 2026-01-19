//
//  ArchiveDetailView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct ArchiveDetailView: View {
    let store: StoreOf<ArchiveDetailFeature>
    
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
            
            Spacer()
        }
        .navigationTitle("Archive 상세 보기")
        .navigationBarTitleDisplayMode(.inline)
    }
}
