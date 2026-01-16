//
//  ArchiveDeepDetailView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveDeepDetailView: View {
    let store: StoreOf<ArchiveDeepDetailFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("더 깊은 상세 화면")
                .font(.largeTitle)
            
            Button("루트 화면으로 가기 (Pop to Root)") {
                store.send(.didTapPopToRoot)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            Button("포즈 디테일 화면으로 가기 (Navigate to Pose)") {
                store.send(.didTapJumpToPose)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .navigationTitle("Archive Deep Detail")
    }
}
