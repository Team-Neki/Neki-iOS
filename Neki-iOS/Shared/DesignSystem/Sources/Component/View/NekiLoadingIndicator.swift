//
//  NekiLoadingIndicator.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/25/26.
//

import SwiftUI
import Lottie

/// 로딩 중임을 알리는 로띠 애니메이션입니다.
///
/// 딤과 문구 없이 애니메이션만 그려, 화면을 덮지 않고 로딩을 알려야 하는 자리에 씁니다.
public struct NekiLoadingIndicator: View {
    public init() {}

    public var body: some View {
        LottieView(animation: .named("ios_loading"))
            .configure { lottieAnimationView in
                lottieAnimationView.contentMode = .scaleAspectFill
                lottieAnimationView.shouldRasterizeWhenIdle = false
            }
            .playbackMode(.playing(.toProgress(1, loopMode: .loop)))
            .frame(width: 150, height: 150)
            .aspectRatio(contentMode: .fill)
    }
}
