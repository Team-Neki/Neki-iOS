//
//  RandomPoseCarouselView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct RandomPoseCarouselView: View {
    @Bindable var store: StoreOf<RandomPoseCarouselFeature>
    
    var body: some View {
        ZStack {
            Color.gray50.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                LinearGradient(colors: [
                    .primary400.opacity(0),
                    .primary400.opacity(1)
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: 136)
                .opacity(0.24)
            }
            .ignoresSafeArea()
            
            ZStack {
                if let pose = store.currentPose {
                    mainContentView(for: pose)
                        .id(pose.id)
                        .transition(activeTransition)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0), value: store.currentPose)
            
            HStack(spacing: .zero) {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { store.send(.tapLeft) }
                
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { store.send(.tapRight) }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        
                        if horizontalAmount < 0 {
                            store.send(.tapRight)
                        } else {
                            store.send(.tapLeft)
                        }
                    }
            )
            
            controlButtons
                .frame(maxHeight: .infinity, alignment: .bottom)
                .disabled(store.isLoading)
            
            if store.isTutorialPresented { tutorialOverlay }
        }
        .animation(.easeInOut, value: store.isTutorialPresented)
        .task { await store.send(.onAppear).finish() }
        .nekiToolbar(
            isOverlay: true,
            center: { NekiToolBar.textCenter("랜덤포즈") }
        )
    }
    
    private var activeTransition: AnyTransition {
        switch store.slideDirection {
        case .previous: return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        case .next: return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case .none: return .opacity
        }
    }
}


// MARK: - Subviews

private extension RandomPoseCarouselView {
    var controlButtons: some View {
        HStack {
            Button {
                store.send(.onTapClose)
            } label: {
                Image(.iconXmarkBlack)
                    .padding(12)
                    .background {
                        Circle()
                            .fill(.white)
                    }
            }
            
            Spacer()
            
            Button {
                guard let pose = store.currentPose else { return }
                store.send(.onTapDetail(pose))
            } label: {
                Image(.iconArrowOutward)
                    .padding(12)
                    .background {
                        Circle()
                            .fill(.primary400)
                    }
            }
            
            Button {
                store.send(.onTapScrap)
            } label: {
                Image(store.isScrapped ? .iconBookmarkFillWhite : .iconBookmarkWhite)
                    .padding(12)
                    .background {
                        Circle()
                            .fill(.primary400)
                    }
            }
        }
        .padding(8)
        .background {
            Capsule()
                .fill(.white.opacity(0.3))
                .strokeBorder(
                    LinearGradient(colors: [
                        .white.opacity(1),
                        .white.opacity(0)
                    ], startPoint: .top, endPoint: .bottom)
                )
        }
        .padding()
    }
    
    var tutorialOverlay: some View {
        ZStack {
            Color.gray900.opacity(0.8)
                .ignoresSafeArea()
            
            VStack {
                LinearGradient(
                    colors: [
                        .primary400.opacity(1),
                        .primary400.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 250)
                .opacity(0.24)
                
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(.imgLeftHand)
                        Text("이전 포즈")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(.imgDividerDots)
                    Spacer()
                    VStack(spacing: 6) {
                        Image(.imgRightHand)
                        Text("다음 포즈")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                
                Button {
                    store.send(.closeTutorialOverlay)
                } label: {
                    Text("랜덤 포즈 시작하기")
                        .nekiFont(.body16SemiBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(stops: [
                                .init(color: .primary400, location: 0.0),
                                .init(color: .primary600, location: 0.53),
                                .init(color: .hex(0xFF334B), location: 0.96),
                            ], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(colors: [
                                        .primary300,
                                        .primary500
                                    ], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1
                                )
                        }
                }
            }
            .padding()
        }
        .transition(.opacity)
        .zIndex(10)
    }
    
    func mainContentView(for pose: Pose) -> some View {
        KFImage(pose.imageURL)
            .placeholder {
                ProgressView()
                    .controlSize(.large)
            }
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: 20))
            .padding()
            .compositingGroup()
    }
}

#Preview {
    RandomPoseCarouselView(store: .init(initialState: RandomPoseCarouselFeature.State(peopleCount: .solo), reducer: { RandomPoseCarouselFeature() }))
}
