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
    
    //MARK: - Properties
    
    @Bindable var store: StoreOf<PoseFeature>
    
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
            left: { NekiToolBar.textLeft("포즈") },
            right: { NekiToolBar.icon(.iconBellFill) }
        )
        .sheet(item: $store.sheetItem) { item in
            switch item {
            case .peopleCountFilter: filterSheetView
            case .randomPoseCountSelection: randomPoseFilterSheetView
            }
        }
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
                items: Array(store.filteredPoses),
                columns: 2
            ) { item in
                FeedImageView(item: item)
                    .onTapGesture {
                        store.send(.imageTapped(item))
                    }
                    .onAppear {
                        guard item == store.filteredPoses.last else { return }
                        store.send(.loadMoreItems)
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
            Button {
                store.send(.onTapFilter)
            } label: {
                Text(store.selectedCountFilterOption?.displayName ?? "인원수")
            }
            .buttonStyle(
                .nekiChip(
                    isHighlighted: store.selectedCountFilterOption != nil,
                    shape: .capsule,
                    style: .dropdown
                )
            )
            
            Button("스크랩") {
                store.send(.onTapScrapMode)
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
                store.send(.onTapRandomPoseRecommend)
            }
        }
    }
    
    @ViewBuilder
    var filterSheetView: some View {
        VStack(spacing: 4) {
            Capsule()
                .frame(width: 45, height: 4)
                .padding(.horizontal, 165)
                .padding(.vertical, 10)
                .foregroundStyle(.gray100)
            
            VStack(alignment: .leading, spacing: 24) {
                Text("인원 수")
                    .nekiFont(.title20SemiBold)
                    .foregroundStyle(.gray900)
                
                ForEach(PeopleCountOption.allCases, id: \.self) { option in
                    Button {
                        store.send(.selectPeopleCount(option))
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            let isHighlighted = store.selectedCountFilterOption == option
                            if isHighlighted {
                                Image(.iconCheckmark)
                            }
                            
                            Text(option.displayName)
                                .nekiFont(isHighlighted ? .body16SemiBold : .body16Medium)
                                .foregroundStyle(isHighlighted ? .gray900 : .gray600)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(.white)
        .presentationDetents([.height(358)]) // TODO: 5인 케이스 사라지면 높이도 바뀔 예정
        .presentationCornerRadius(20)
        .presentationDragIndicator(.hidden)
    }
    
    var randomPoseFilterSheetView: some View {
        VStack(spacing: 4) {
            Capsule()
                .frame(width: 45, height: 4)
                .padding(.horizontal, 165)
                .padding(.vertical, 10)
                .foregroundStyle(.gray100)
            
            VStack(alignment: .leading, spacing: 24) {
                Text("랜덤 포즈 추천을 위해\n촬영 중인 인원수를 선택해주세요")
                    .nekiFont(.title20SemiBold)
                    .foregroundStyle(.gray900)
                
                ForEach(PeopleCountOption.allCases, id: \.self) { option in
                    Button {
                        store.send(.selectPeopleCountForRandomPose(option))
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            let isHighlighted: Bool = store.selectedRandomPoseCountSelectionOption == option
                            if isHighlighted {
                                Image(.iconCheckmark)
                            }
                            
                            Text(option.displayName)
                                .nekiFont(isHighlighted ? .body16SemiBold : .body16Medium)
                                .foregroundStyle(isHighlighted ? .gray900 : .gray600)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                HStack(spacing: 12) {
                    let designTotalWidth: CGFloat = 375.0
                    let designPadding: CGFloat = 20.0 * 2
                    let designSpacing: CGFloat = 12.0
                    let contentWidth = designTotalWidth - designPadding - designSpacing
                    let cancelFactor = 93.0 / contentWidth
                    let selectFactor = 230.0 / contentWidth
                    
                    Button {
                        store.send(.binding(.set(\.sheetItem, nil)))
                    } label: {
                        Text("취소")
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .buttonStyle(.nekiCTA(.secondary))
                    .containerRelativeFrame(.horizontal) { length, _ in
                        let availableSpace = length - designPadding - designSpacing
                        return availableSpace * cancelFactor
                    }
                    
                    Button {
                        store.send(.onTapStartRandomPoseCarousel)
                    } label: {
                        Text("선택하기")
                    }
                    .buttonStyle(.nekiCTA(.primary))
                    .containerRelativeFrame(.horizontal) { length, _ in
                        let availableSpace = length - designPadding - designSpacing
                        return availableSpace * selectFactor
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(.white)
        .presentationDetents([.height(458)])
        .presentationCornerRadius(20)
        .presentationDragIndicator(.hidden)
    }
}


// MARK: - Nested Types

extension PoseView {
    enum SheetType: Identifiable {
        /// 포즈 인원수 필터 시트
        case peopleCountFilter
        /// 랜덤포즈 인원수 선택 시트
        case randomPoseCountSelection
        
        var id: Self { self }
    }
}

#Preview {
    AppCoordinatorView(store: .init(initialState: AppCoordinator.State.mainTab(.init()), reducer: { AppCoordinator() }))
}
