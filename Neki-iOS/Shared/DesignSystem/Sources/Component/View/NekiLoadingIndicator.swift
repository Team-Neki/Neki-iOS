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
/// 딤과 문구 없이 애니메이션만 그립니다. 전체 화면 로딩(``LoadingView``)과 본문 자리 로딩이 함께 씁니다.
/// 로딩 상태에 맞춰 띄울 때는 표시 정책(표시 지연·최소 노출)이 적용되도록 직접 그리지 말고
/// `nekiLoading(isPresented:style:message:policy:)`에 ``NekiLoadingStyle/inline``을 넘겨 씁니다.
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
