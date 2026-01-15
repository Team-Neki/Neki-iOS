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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            filterBarView
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .padding(.bottom, 12)
            
            ZStack(alignment: .bottom) {
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
                    .padding(.bottom, 76)
                }
                .scrollIndicators(.never)
                
                ChipFloatingButton(.randomPose) {
                    // TODO: - 랜덤포즈로 이동
                }
                .padding(.bottom, 24)
            }
            
        }
        .nekiToolbar(
            left: .text(
                "포즈",
                action: nil
            ),
            right: .icon(
                .iconBellFill,
                action: {
                    // TODO: - 알림으로 이동
                })
        )
        .task {
            await store.send(.onAppear).finish()
        }
    }
}


// MARK: - PoseView + SubViews

private extension PoseView {
    var filterBarView: some View {
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
