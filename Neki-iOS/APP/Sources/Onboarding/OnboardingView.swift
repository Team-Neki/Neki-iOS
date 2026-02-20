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
    
    var body: some View {
        VStack(spacing: 0) {
            
            TabView(selection: $store.currentPage) {
                ForEach(store.loopedContents.indices, id: \.self) { index in
                    onboardingPageView(content: store.loopedContents[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            customPageControl
                .padding(.bottom, 24)
            
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
    
    private var customPageControl: some View {
        HStack(spacing: 8) {
            ForEach(0..<store.originalCount, id: \.self) { index in
                let isCurrent = (store.currentPage == index + 1) ||
                                (store.currentPage == 0 && index == store.originalCount - 1) ||
                                (store.currentPage == store.originalCount + 1 && index == 0)
                
                Circle()
                    .fill(isCurrent ? Color.primary400 : Color.gray50)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: store.currentPage)
            }
        }
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
                
                highlightedTitle(content: content)
                    .nekiFont(.title28SemiBold)
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
    
    private func highlightedTitle(content: OnboardingItem) -> Text {
        var attributedString = AttributedString(content.title)
        
        if let range = attributedString.range(of: content.highlightTitle) {
            attributedString[range].font = .neki(.title28Bold)
        }
        
        return Text(attributedString)
    }
}

#Preview {
    OnboardingView(
        store: Store(initialState: OnboardingCoordinator.State()) {
            OnboardingCoordinator()
        }
    )
}
