//
//  OnboardingCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 2/6/26.
//

import SwiftUI
import ComposableArchitecture

// 온보딩에는 별도 플로우가 없어서 필요없을 것 같긴한데 일단...
public struct OnboardingCoordinatorView: View {
    @Bindable var store: StoreOf<OnboardingCoordinator>
    
    public var body: some View {
        OnboardingView(store: store)
    }
}
