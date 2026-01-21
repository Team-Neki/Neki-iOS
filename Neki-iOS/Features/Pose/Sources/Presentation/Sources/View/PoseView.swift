//
//  PoseView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture

struct PoseView: View {
    
    //MARK: - Property Wrappers
    
    @State private var isFilterBarVisible: Bool = true
    @State private var lastDragPoint: CGFloat = 0
    @State private var isSheetVisible: Bool = false
    
    //MARK: - Properties
    
    let store: StoreOf<PoseFeature>
    let filterNumberOption = ["1인", "2인", "3인", "4인", "5인 이상"]
    
    //MARK: - Main Body
    
    var body: some View {
        ZStack(alignment: .top) {
            
            masonryView
            
            filterBar
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .padding(.bottom, 12)
                .background(.white)
                .offset(y: isFilterBarVisible ? 0 : -100)
            
            randomPoseButton
                .padding(.bottom, 76)
            
        }
        .nekiToolbar(
            left: .text("포즈", action: nil),
            right: .icon(.iconBellFill, action: {})
        )
        .sheet(isPresented: $isSheetVisible, content: {
            filterSheetView
                .presentationDetents([.height(358)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        })
        .task {
            await store.send(.onAppear).finish()
        }
    }
}


// MARK: - PoseView + SubViews

private extension PoseView {
    @ViewBuilder
    var masonryView: some View {
        ScrollView {
            MasonryGridView(
                items: Array(store.filteredItems),
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
                        isFilterBarVisible = diff < 0 ? false : true
                    }
                    
                    lastDragPoint = currentPoint
                }
                .onEnded {_ in
                    lastDragPoint = 0
                }
        )
    }
    
    @ViewBuilder
    var filterBar: some View {
        HStack(alignment: .center, spacing: 6) {
            Button(store.state.selectedPeopleCount ?? "인원수") {
                store.send(.onTapFilter)
                isSheetVisible = true
            }
            .buttonStyle(
                .nekiChip(
                    isHighlighted: store.state.selectedPeopleCount != nil,
                    shape: .capsule,
                    style: .dropdown
                )
            )
            
            Button("스크랩") {
                store.send(.onTapScrap)
            }
            .buttonStyle(
                .nekiChip(
                    isHighlighted: store.state.isSelectedScrap,
                    shape: .capsule,
                    style: .normal
                )
            )
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var randomPoseButton: some View {
        VStack {
            Spacer()
            ChipFloatingButton(.randomPose) {
                // TODO: - 랜덤포즈로 이동
            }
        }
    }
    
    @ViewBuilder
    var filterSheetView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("인원 수")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
            
            VStack(alignment: .leading, spacing: 28) {
                ForEach(filterNumberOption, id: \.self) { count in
                    Button {
                        store.send(.selectPeopleCount(count))
                        isSheetVisible = false
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            if store.selectedPeopleCount == count {
                                Image(.iconCheckmark)
                            }
                            
                            Text(count)
                                .nekiFont(store.selectedPeopleCount == count ? .body16SemiBold : .body16Medium)
                                .foregroundStyle(store.selectedPeopleCount == count ? .gray900 : .gray600)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(.white)
    }
}
