//
//  OnboardingItem.swift
//  Neki-iOS
//
//  Created by OneTen on 2/6/26.
//

import UIKit

struct OnboardingItem: Hashable, Identifiable {
    let id = UUID()
    let badge: String
    let title: String
    let imageName: UIImage
}

extension OnboardingItem {
    static let list: [OnboardingItem] = [
        .init(
            badge: "빠른 네컷 부스 탐색",
            title: "네컷 부스 정보를\n빠르고 쉽게 찾아요",
            imageName: .onboarding1
        ),
        .init(
            badge: "포즈 걱정 없는 촬영 경험",
            title: "인원수에 맞는\n포즈를 추천받아요",
            imageName: .onboarding2
        ),
        .init(
            badge: "네컷 사진 아카이빙",
            title: "흩어지기 쉬운 사진을\n한곳에 모아요",
            imageName: .onboarding3
        )
    ]
}
