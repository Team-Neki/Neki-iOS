//
//  PoseDeepDetailView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

struct PoseDeepDetailView: View {
    let store: StoreOf<PoseDeepDetailFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("더 깊은 상세 화면")
                .font(.largeTitle)
            
            Button("로그아웃") {
                store.send(.didTapLogoutButton)
            }
            .foregroundStyle(.red)
            
            Button("루트 화면으로 가기 (Pop to Root)") {
                store.send(.didTapPopToRoot)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .navigationTitle("Deep Detail")
    }
}
