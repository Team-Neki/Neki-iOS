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
    @State private var sheetHeight: CGFloat = 1
    
    //MARK: - Properties
    
    @Bindable var store: StoreOf<PoseFeature>
    
    //MARK: - Main Body
    
    var body: some View {
        ZStack(alignment: .top) {
            
            masonryView
            
            filterHeader
                .background(.white)
                .offset(y: isFilterBarVisible ? 0 : -Constants.filterHeaderHeight)
            
            randomPoseButton
                .padding(.bottom, 76)
            
            if store.isSortMenuPresented {
                sortMenuDismissArea
                
                sortMenu
            }
            
        }
        .nekiToolbar(
            left: { NekiToolBar.textLeft("포즈") },
            right: { NekiToolBar.items {
                Button {
                    store.send(.qrScanButtonTapped)
                } label: {
                    Image(.iconQrCode)
                }
                
                Button {
                    store.send(.notificationButtonTapped)
                } label: {
                    Image(.iconBellFill)
                }
            } }
        )
        .sheet(item: $store.sheetItem) { item in
            Group {
                switch item {
                case .peopleCountFilter:
                    PeopleCountFilterSheet(contentHeight: $sheetHeight, store: store)
                        .autoSizingDetent($sheetHeight)
                case .randomPoseCountSelection:
                    RandomPoseSelectionSheet(contentHeight: $sheetHeight, store: store)
                        .autoSizingDetent($sheetHeight)
                }
            }
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
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
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: .zero) {
                        Color.clear
                            .frame(height: .zero)
                            .id(Constants.scrollTopAnchorID)
                        
                        MasonryGridView(
                            items: store.visiblePoses,
                            columns: 2,
                            estimatedHeight: { item in
                                guard let width = item.width,
                                      let height = item.height,
                                      width > 0,
                                      height > 0
                                else { return nil }

                                return CGFloat(height) / CGFloat(width)
                            }
                        ) { item in
                            FeedImageView(
                                item: item,
                                onTapBookmark: { store.send(.onTapBookmark(item)) }
                            )
                            .onTapGesture {
                                store.send(.imageTapped(item))
                            }
                            .onAppear {
                                guard item.id == store.lastVisiblePoseID else { return }
                                store.send(.loadMoreItems)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, Constants.filterHeaderHeight)
                        .padding(.bottom, 76)
                        .nekiImageMaximumDisplayHeight(proxy.size.height)
                    }
                }
                .scrollIndicators(.never)
                .id(store.isSelectedScrap ? "Scrapped" : "General")
                .refreshable { await store.send(.onRefresh).finish() }
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
                // 북마크 전환은 `.id`로 스크롤 뷰를 새로 만듭니다. 이 감시가 `.id` 앞에 있으면 함께 새로 만들어져 바뀐 값을 받지 못합니다.
                .onChange(of: store.scrollToTopGeneration) {
                    scrollProxy.scrollTo(Constants.scrollTopAnchorID, anchor: .top)
                    withAnimation(.smooth) { isFilterBarVisible = true }
                }
            }
        }
    }
    
    /// 태그 바와 "N개의 포즈"·정렬 행을 묶은 머리글입니다. 목록을 내리면 위로 숨습니다.
    @ViewBuilder
    var filterHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            filterBar
                .padding(.vertical, 4)
            
            poseCountSortRow
        }
        .padding(.bottom, 12)
    }
    
    /// `북마크 | 인원수 · 친구 · 커플 · 썸` 순서의 태그 바입니다.
    ///
    /// 기본 글자 크기에서도 화면 폭을 거의 채워서, 글자를 키우면 잘리지 않고 가로로 넘기도록 스크롤로 감쌉니다.
    @ViewBuilder
    var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: 6) {
                Button("북마크") {
                    store.send(.onTapScrapMode)
                }
                .buttonStyle(
                    .nekiChip(
                        isHighlighted: store.state.isSelectedScrap,
                        shape: .capsule,
                        style: .normal
                    )
                )
                
                Rectangle()
                    .fill(.gray75)
                    .frame(width: 0.5, height: 24)
                
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
                
                ForEach(PoseRelation.allCases, id: \.self) { relation in
                    Button(relation.displayName) {
                        store.send(.onTapRelationFilter(relation))
                    }
                    .buttonStyle(
                        .nekiChip(
                            isHighlighted: store.selectedRelationFilterOption == relation,
                            shape: .capsule,
                            style: .normal
                        )
                    )
                }
            }
        }
        .scrollIndicators(.never)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }
    
    /// 왼쪽에 "N개의 포즈", 오른쪽에 정렬 기준을 둔 행입니다. 개수를 모르면 개수만 숨깁니다.
    @ViewBuilder
    var poseCountSortRow: some View {
        HStack(spacing: .zero) {
            if let poseCount = store.displayedPoseCount {
                Text(poseCountTitle(poseCount))
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray400)
            }
            
            Spacer(minLength: .zero)
            
            sortLabel
        }
        .frame(height: 20)
        .padding(.horizontal, 20)
    }
    
    /// 개수만 굵은 서체와 진한 색으로 강조한 포즈 개수 문구입니다.
    func poseCountTitle(_ count: Int) -> AttributedString {
        var countText = AttributedString("\(count)")
        countText.font = .neki(.body14SemiBold)
        countText.foregroundColor = Color.gray600
        return countText + AttributedString("개의 포즈")
    }
    
    /// 정렬 기준입니다. 8-1은 정렬 메뉴가 꺼져 있어 누를 수 없는 글자로만 보입니다.
    @ViewBuilder
    var sortLabel: some View {
        if PoseFeature.State.isSortMenuEnabled {
            Button {
                store.send(.onTapSortMenu)
            } label: {
                HStack(spacing: .zero) {
                    sortTitle
                    
                    Image(.iconChipDown)
                }
            }
        } else {
            sortTitle
        }
    }
    
    var sortTitle: some View {
        Text(store.selectedSortOption.displayName)
            .nekiFont(.body14SemiBold)
            .foregroundStyle(.gray600)
    }
    
    /// 정렬 메뉴입니다. 개수 행 6pt 아래에, 오른쪽 끝을 정렬 라벨에 맞춰 띄웁니다.
    @ViewBuilder
    var sortMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PoseSortOption.allCases, id: \.self) { option in
                let isSelected = store.selectedSortOption == option
                Button {
                    store.send(.selectSortOption(option))
                } label: {
                    Text(option.displayName)
                        .nekiFont(isSelected ? .body14SemiBold : .body14Regular)
                        .foregroundStyle(isSelected ? .gray900 : .gray700)
                        .frame(height: 20)
                }
                .buttonStyle(SortMenuButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .frame(width: Constants.sortMenuWidth)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        .padding(.top, Constants.sortMenuTopPadding)
        .padding(.trailing, Constants.sortMenuTrailingPadding)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    /// 정렬 메뉴가 열려 있을 때 메뉴 바깥을 누르면 메뉴만 닫습니다.
    var sortMenuDismissArea: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { store.send(.dismissSortMenu) }
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
}


// MARK: - Subviews

private extension PoseView {
    struct PeopleCountFilterSheet: View {
        @Binding var contentHeight: CGFloat
        
        let store: StoreOf<PoseFeature>
        
        var body: some View {
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
                    
                    ForEach(PeopleCountOption.allCases.filter({ $0 != .overQuartet }), id: \.self) { option in
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
                }
                .padding()
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .safeAreaPadding(.bottom)
            .presentationBackground(.white)
        }
    }
    
    struct RandomPoseSelectionSheet: View {
        @Binding var contentHeight: CGFloat
        
        let store: StoreOf<PoseFeature>
        
        var body: some View {
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
                    
                    ForEach(PeopleCountOption.allCases.filter({ $0 != .overQuartet }), id: \.self) { option in
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
                }
                .padding()
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .safeAreaPadding(.bottom)
            .presentationBackground(.white)
        }
    }
    
    /// 정렬 메뉴의 한 줄입니다. 누르는 동안 배경을 옅은 회색으로 바꿉니다(Archive 정렬 메뉴와 같음).
    struct SortMenuButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 5)
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(configuration.isPressed ? .gray50 : .white)
        }
    }
}


// MARK: - Constants

private extension PoseView {
    enum Constants {
        /// 태그 바(칩 34, 위아래 4), 간격 12, 개수 행 20, 아래 12를 더한 머리글 높이입니다. 목록 위 여백과 머리글을 숨길 때 올리는 거리에 함께 씁니다.
        static let filterHeaderHeight: CGFloat = 86
        static let scrollTopAnchorID = "POSE_SCROLL_TOP"
        /// 정렬 메뉴는 머리글 위에서 80(개수 행 6pt 아래)에 뜹니다.
        static let sortMenuTopPadding: CGFloat = 80
        static let sortMenuTrailingPadding: CGFloat = 19
        static let sortMenuWidth: CGFloat = 106
    }
}


// MARK: - Helpers

extension View {
    func autoSizingDetent(_ heightBinding: Binding<CGFloat>) -> some View {
        self
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { newHeight in
                guard newHeight > .zero, abs(heightBinding.wrappedValue - newHeight) > 1 else { return }
                heightBinding.wrappedValue = newHeight
            }
            .presentationDetents([.height(heightBinding.wrappedValue)])
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


// MARK: - Preview

#Preview("기본") {
    PoseView.preview(state: PoseFeature.State())
}

#Preview("친구 선택") {
    PoseView.preview(state: {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)
        return state
    }())
}

private extension PoseView {
    /// 인원수를 섞은 포즈 12개를 불러오는 미리보기 화면입니다. 서버와 분석 이벤트는 부르지 않습니다.
    static func preview(state: PoseFeature.State) -> some View {
        let peopleCounts: [PeopleCountOption] = [.solo, .duo, .trio]
        let poses = (1...12).map { id in
            Pose(
                id: id,
                peopleCountOption: peopleCounts[id % peopleCounts.count],
                imageURL: nil,
                isScrapped: false,
                contentType: .jpeg,
                width: 3,
                height: 4
            )
        }
        return NavigationStack {
            PoseView(
                store: Store(initialState: state) {
                    PoseFeature()
                } withDependencies: {
                    $0.poseClient.fetchPoseList = { _, _, _ in (poses, false) }
                    $0.poseClient.fetchScrappedPoseList = { _, _, _ in ([], false) }
                    $0.analyticsClient.logEvent = { _ in }
                }
            )
        }
    }
}
