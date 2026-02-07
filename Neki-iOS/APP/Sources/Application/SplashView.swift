//
//  SplashView.swift
//  Neki-iOS
//
//  Created by OneTen on 2/6/26.
//

import SwiftUI

struct SplashView: View {
    let gradientColor: LinearGradient = LinearGradient(
        colors: [
            .primary500,
            .primary300
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Spacer()
                Image(.imageSplashLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 98)
                    .padding(.top, 177)
                Spacer()
            }
            Spacer()
        }
        .ignoresSafeArea()
        .background(gradientColor)
    }
}

#Preview {
    SplashView()
}
