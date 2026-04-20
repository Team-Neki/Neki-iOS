//
//  DirectionAppsSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/11/26.
//

import SwiftUI
import ComposableArchitecture

struct DirectionAppsSheet: View {
    let store: StoreOf<MapFeature>
    let photoBooth: PhotoBooth
    
    var body: some View {
        VStack(spacing: 10) {
            Text("길찾기 앱 선택")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 52) {
                ForEach(DirectionAppType.allCases, id: \.self) { app in
                    VStack(spacing: 8) {
                        let appIconShape = RoundedRectangle(cornerRadius: 12)
                        
                        Image(app.imageResources)
                            .clipShape(appIconShape)
                            .overlay { appIconShape.stroke(.gray50, lineWidth: 1) }
                        
                        Text(app.displayName)
                            .nekiFont(.body14Medium)
                            .foregroundStyle(.gray900)
                    }
                    .contentShape(.rect)
                    .onTapGesture { store.send(.didSelectDirectionApp(app)) }
                }
            }
            
            Spacer()
        }
        .presentationDetents([.height(162)])
        .presentationCornerRadius(20)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}
