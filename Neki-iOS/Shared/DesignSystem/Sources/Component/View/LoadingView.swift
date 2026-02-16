//
//  LoadingView.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/16/26.
//

import SwiftUI
import Lottie

public struct LoadingView: View {
    private let message: String
    
    public init(message: String = "") {
        self.message = message
    }
    
    public var body: some View {
        ZStack {
            Color.gray900.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                LottieView(animation: .named("ios_loading"))
                    .configure { lottieAnimationView in
                        lottieAnimationView.contentMode = .scaleAspectFill
                        lottieAnimationView.shouldRasterizeWhenIdle = false
                    }
                    .playbackMode(.playing(.toProgress(1, loopMode: .loop)))
                    .frame(width: 150, height: 150)
                    .aspectRatio(contentMode: .fill)
                
                Text(message)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.white)
            }
        }
        .presentationBackground(.clear)
    }
}
