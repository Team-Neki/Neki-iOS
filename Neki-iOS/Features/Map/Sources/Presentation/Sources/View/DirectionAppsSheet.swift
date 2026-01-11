//
//  DirectionAppsSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/11/26.
//

import SwiftUI
import ComposableArchitecture

struct DirectionAppsSheet: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("길찾기 앱 선택")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 36) {
                ForEach(DirectionAppType.allCases, id: \.self) { app in
                    VStack(spacing: 8) {
                        Image(app.imageResources)
                        
                        Text(app.displayName)
                            .nekiFont(.body14Medium)
                            .foregroundStyle(.gray900)
                    }
                }
            }
        }
        .presentationDetents([.height(196)])
        .presentationCornerRadius(24) // TODO: 곡률 디자인 시안 확인
        .padding()
    }
}

#Preview {
    TabView {
        NaverMapView(store: Store(initialState: MapFeature.State(), reducer: { MapFeature() }))
    }
}
