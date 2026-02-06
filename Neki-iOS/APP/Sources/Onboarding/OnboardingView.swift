//
//  OnboardingView.swift
//  Neki-iOS
//
//  Created by OneTen on 2/6/26.
//

import SwiftUI
import ComposableArchitecture

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingCoordinator>
    
    let contents = OnboardingItem.list
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $store.currentPage) {
                ForEach(contents.indices, id: \.self) { index in
                    onboardingPageView(content: contents[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .onAppear {
                setupPageControlAppearance()
            }
            
            Button {
                store.send(.startButtonTapped)
            } label: {
                Text("회원가입 및 로그인")
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.primary400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
    
    // 인디케이터 색상
    private func setupPageControlAppearance() {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(.primary400)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(.gray50)
    }
}

extension OnboardingView {
    @ViewBuilder
    private func onboardingPageView(content: OnboardingItem) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(content.badge)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.primary400)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.primary25)
                    .clipShape(Capsule())
                
                Text(content.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.gray900)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 60)
            .padding(.bottom, 28)
            
            Image(uiImage: content.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingCoordinatorView(store: .init(initialState: OnboardingCoordinator.State(), reducer: {
        OnboardingCoordinator()
    }))
}
