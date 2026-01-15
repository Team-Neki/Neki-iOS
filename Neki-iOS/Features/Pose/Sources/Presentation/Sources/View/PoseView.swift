//
//  PoseView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture

struct PoseView: View {
    
    let store: StoreOf<PoseFeature>
    
    @State private var isFilterBarVisible: Bool = true
    @State private var lastDragPoint: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            
            ScrollView {
                MasonryGridView(
                    items: Array(store.items),
                    columns: 2
                ) { item in
                    FeedImageView(item: item)
                        .onTapGesture {
                            store.send(.imageTapped(item))
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 54)
                .padding(.bottom, 76)
            }
            .scrollIndicators(.never)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        let currentPoint = value.translation.height
                        let diff = currentPoint - lastDragPoint
                        
                        withAnimation(.smooth) {
                            if diff < 0 {
                                // 아래로 스크롤
                                isFilterBarVisible = false
                            } else {
                                // 위로 스크롤
                                isFilterBarVisible = true
                            }
                        }
                        
                        lastDragPoint = currentPoint
                    }
                    .onEnded {_ in
                        lastDragPoint = 0
                    }
            )
            
            filterBar
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .padding(.bottom, 12)
                .background(.white)                         // 뒷 배경 불투명
//                .background(.white.opacity(0.5))          // 뒷 배경 반투명
                .offset(y: isFilterBarVisible ? 0 : -100)   // 화면 위로 올라가며 사라지는 애니메이션
//                .opacity(isFilterBarVisible ? 1 : 0)      // 투명화하며 사라지는 애니메이션
            
            VStack {
                Spacer()
                ChipFloatingButton(.randomPose) {
                    // TODO: - 랜덤포즈로 이동
                }
            }
            .padding(.bottom, 24)

        }
        .nekiToolbar(
            left: .text("포즈", action: nil),
            right: .icon(.iconBellFill, action: {})
        )
        .task {
            await store.send(.onAppear).finish()
        }
    }
}

// MARK: - PoseView + SubViews

private extension PoseView {
    var filterBar: some View {
        HStack(alignment: .center, spacing: 6) {
            Button("인원수") {
                store.send(.onTapFilter)
            }
            .buttonStyle(.nekiChip(isHighlighted: false, shape: .capsule, style: .dropdown))
            
            Button("스크랩") {
                store.send(.onTapScrap)
            }
            .buttonStyle(.nekiChip(isHighlighted: false, shape: .capsule, style: .normal))
            
            Spacer()
        }
    }
}

#Preview {
    MainTabCoordinatorView(store: Store(initialState: MainTabCoordinator.State()) {
            MainTabCoordinator()
        }
    )
}
