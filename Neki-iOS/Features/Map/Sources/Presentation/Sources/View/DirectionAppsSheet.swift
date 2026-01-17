//
//  DirectionAppsSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/11/26.
//

import SwiftUI
import ComposableArchitecture

struct DirectionAppsSheet: View {
    @Environment(\.openURL) private var openURL
    
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
                    .onTapGesture { handleAppSelection(app) }
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


// MARK: - DirectionAppsSheet + Methods

private extension DirectionAppsSheet {
    func handleAppSelection(_ app: DirectionAppType) {
        // TODO: 검색 정보 유효하지 않을 경우에는 앱이 반응을 안한다고 생각할 수 있음. 보완 필요
        guard let universalLink = app.connectLink(coordinate: photoBooth.coordinate, name: photoBooth.name) else { return }
        openURL(universalLink)
    }
}
