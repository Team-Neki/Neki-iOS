//
//  NearPhotoBoothListSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/8/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct NearPhotoBoothListSheet: View {
    @Environment(\.nekiSheetScrollStateHandler) private var sheetScrollStateHandler
    @Bindable var store: StoreOf<PhotoBoothListFeature>
    @Namespace private var tabNamespace
    @State private var isVerticalScrollAtTop: Bool = true
    @State private var favoriteButtonOverrides: [PhotoBooth.ID: Bool] = [:]
    @State private var pendingFavoriteRemovalIDs: Set<PhotoBooth.ID> = []
    @State private var pendingFavoriteRemovalBooths: IdentifiedArrayOf<PhotoBooth> = []
    @State private var favoriteRemovalReferenceBooths: IdentifiedArrayOf<PhotoBooth> = []
    @State private var delayedFavoriteTasks: [PhotoBooth.ID: Task<Void, Never>] = [:]

    private let brandNameFormatter = PhotoBoothNameFormatter()

    private enum Constants {
        static let verticalScrollCoordinateSpaceName = "NearPhotoBoothListSheet.VerticalScroll"
        static let scrollTopThreshold: CGFloat = -1
        /// 시트 손잡이(24pt)와 검색 결과 첫 줄 사이의 간격입니다.
        static let searchResultTopPadding: CGFloat = 4
        static let searchResultSectionSpacing: CGFloat = 4
    }

    private enum FavoriteRemovalEffect {
        static let delay: Duration = .milliseconds(260)
        static let overrideResetDelay: Duration = .milliseconds(400)
        static let scale: CGFloat = 0.98

        static var animation: Animation { .spring(response: 0.28, dampingFraction: 0.58) }

        static var transition: AnyTransition { .opacity.combined(with: .scale(scale: scale)) }
    }
    
    init(store: StoreOf<PhotoBoothListFeature>) { self.store = store }
    
    var body: some View {
        ScrollView(.vertical) {
            verticalScrollTopReader

            if store.isSearchResultPresented {
                searchResultPhotoBoothListSection
            } else {
                photoBoothBrandFilterOptionsSection

                VStack(spacing: 12) {
                    listTabBar

                    Group {
                        switch store.selectedTab {
                        case .nearby:
                            nearByPhotoBoothListSection
                        case .favorite:
                            favoritePhotoBoothListSection
                        }
                    }
                }
            }
        }
        .coordinateSpace(name: Constants.verticalScrollCoordinateSpaceName)
        .onPreferenceChange(NearPhotoBoothListScrollOffsetPreferenceKey.self) { offset in
            updateVerticalScrollTopState(offset)
        }
        .onChange(of: store.isSearchResultPresented) { _, _ in
            // 목록을 통째로 갈아 끼우면 스크롤이 맨 위로 돌아가므로 시트가 아는 위치도 함께 맞춥니다.
            isVerticalScrollAtTop = true
            sheetScrollStateHandler.updateIsAtTop(true)
        }
        .sheet(isPresented: $store.isSearchResultBrandFilterSheetPresented) {
            PhotoBoothBrandFilterSheet(store: store)
        }
        .onDisappear {
            delayedFavoriteTasks.values.forEach { $0.cancel() }
            delayedFavoriteTasks.removeAll()
            pendingFavoriteRemovalIDs.removeAll()
            pendingFavoriteRemovalBooths.removeAll()
            favoriteRemovalReferenceBooths.removeAll()
            favoriteButtonOverrides.removeAll()
            isVerticalScrollAtTop = true
            sheetScrollStateHandler.updateIsAtTop(true)
        }
    }
}


// MARK: - NearPhotoBoothListSheet + Subviews

private extension NearPhotoBoothListSheet {
    var verticalScrollTopReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: NearPhotoBoothListScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named(Constants.verticalScrollCoordinateSpaceName)).minY
                )
        }
        .frame(height: .zero)
    }

    var photoBoothBrandFilterOptionsSection: some View {
        Section {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 2) {
                    ForEach(store.selectableBrands, id: \.self) { brand in
                        filterCell(brand)
                    }
                }
            }
            .scrollIndicators(.never)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollDisabled(false)
        } header: {
            HStack(spacing: .zero) {
                Text("네컷 사진 브랜드")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .padding(.top, 4)
                    .nekiFont(.title18Bold)
                
                Button {
                    store.send(.didTapBrandReorderButton)
                } label: {
                    Text("편집")
                        .nekiFont(.body14Medium)
                        .foregroundStyle(.gray600)
                }
                .padding(.top, 4)
                .padding(.trailing, 20)
            }
        }
    }
    
    @ViewBuilder
    func filterCell(_ brand: PhotoBoothBrand) -> some View {
        let isSelected: Bool = store.filteredBrands.contains(brand)
        
        Button {
            store.send(.selectFilterOption(brand))
        } label: {
            VStack(spacing: 8) {
                KFImage(brand.imageURL)
                    .resizable()
                    .onFailureImage(.imgDefaultBrandOriginal)
                    .frame(width: 56, height: 56)
                    .clipShape(.circle)
                    .overlay {
                        ZStack {
                            Circle()
                                .fill(isSelected ? .primary400.opacity(0.5) : .clear)
                            
                            if isSelected {
                                Image(.iconCheckmarkWhite)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                
                Text(brandNameFormatter.format(brand: brand))
                    .font(.neki(isSelected ? .body14SemiBold : .body14Medium))
                    .foregroundStyle(isSelected ? .primary400 : .gray900)
                    .lineLimit(2)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 56)
            .padding(.horizontal, 5)
            .padding(.bottom, 48)
        }
    }
    
    var listTabBar: some View {
        HStack(spacing: 0) {
            ForEach(PhotoBoothListFeature.ListTab.allCases) { tab in
                let isSelected = store.selectedTab == tab
                
                Button {
                    store.send(.selectTab(tab), animation: .easeInOut(duration: 0.2))
                } label: {
                    HStack(spacing: 2) {
                        Image(tab == .nearby ? .iconPinClip : .iconDoubleHeart)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .saturation(isSelected ? 1 : 0)
                        
                        Text(tab.title)
                            .nekiFont(.body14SemiBold)
                            .foregroundStyle(isSelected ? .gray800 : .gray500)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white)
                                .matchedGeometryEffect(id: "selectedPhotoBoothListTab", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(4)
        .background(.gray50)
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal, 20)
    }

    var nearByPhotoBoothListSection: some View {
        Section {
            if store.visibleBooths.isEmpty {
                unavailableView("이 지역에 네컷 사진관이 없어요!")
            } else {
                LazyVStack(alignment: .leading, spacing: .zero) {
                    ForEach(store.visibleBooths) { photoBooth in
                        photoBoothCell(photoBooth)
                            .transition(Self.FavoriteRemovalEffect.transition)
                    }
                }
                .animation(Self.FavoriteRemovalEffect.animation, value: store.visibleBooths.map(\.id))
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    var favoritePhotoBoothListSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                favoriteBoothCountText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                if displayedFavoriteBooths.isEmpty {
                    unavailableView("저장한 포토부스가 없어요.")
                } else {
                    LazyVStack(alignment: .leading, spacing: .zero) {
                        ForEach(displayedFavoriteBooths) { photoBooth in
                            photoBoothCell(photoBooth)
                                .transition(Self.FavoriteRemovalEffect.transition)
                        }
                    }
                    .animation(Self.FavoriteRemovalEffect.animation, value: displayedFavoriteBoothIDs)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// 검색 결과를 탭 없이 개수, `브랜드` 칩, 목록으로 노출합니다.
    var searchResultPhotoBoothListSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Constants.searchResultSectionSpacing) {
                searchResultBoothCountText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // 결과에 브랜드가 하나도 없으면 시트를 열어도 고를 게 없으므로 칩을 두지 않습니다.
                if store.selectableBrands.isEmpty == false {
                    searchResultBrandFilterChipRow
                }

                if store.visibleBooths.isEmpty {
                    unavailableView("조건에 맞는 포토부스가 없어요.")
                } else {
                    LazyVStack(alignment: .leading, spacing: .zero) {
                        ForEach(store.visibleBooths) { photoBooth in
                            photoBoothCell(photoBooth)
                        }
                    }
                }
            }
            .padding(.top, Constants.searchResultTopPadding)
        }
        .frame(maxHeight: .infinity)
    }

    var searchResultBoothCountText: some View {
        Text("\(store.visibleBooths.count)곳의 포토부스를 찾았어요.")
            .nekiFont(.body14SemiBold)
            .foregroundStyle(.gray600)
    }

    /// 브랜드 필터 바텀시트를 여는 칩입니다.
    ///
    /// 고른 브랜드가 없으면 `브랜드`, 있으면 첫 브랜드 이름(둘 이상이면 나머지 개수까지)을 적고 채워진 모양이 됩니다.
    var searchResultBrandFilterChipRow: some View {
        HStack(spacing: .zero) {
            Button(store.searchResultBrandFilterChipTitle) {
                store.send(.didTapSearchResultBrandFilterChip)
            }
            .buttonStyle(SearchResultBrandFilterChipStyle(isHighlighted: store.filteredBrands.isEmpty == false))

            Spacer(minLength: .zero)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    var favoriteBoothCountText: some View {
        HStack(spacing: 0) {
            Text("저장한 포토부스 총 ")
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray300)

            Text("\(store.favoriteBoothCount)")
                .nekiFont(.body14SemiBold)
                .foregroundStyle(.gray400)

            Text("곳")
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray300)
        }
    }

    @ViewBuilder
    func photoBoothCell(_ photoBooth: PhotoBooth) -> some View {
        HStack(spacing: 16) {
            KFImage(photoBooth.brand.imageURL)
                .resizable()
                .onFailureImage(.imgDefaultBrandOriginal)
                .cancelOnDisappear(true)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.gray75, lineWidth: 0.5) }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(photoBooth.brand.name)
                    .nekiFont(.title18SemiBold)
                    .foregroundStyle(.gray900)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(photoBooth.name)
                        .nekiFont(.body14Medium)
                        .foregroundStyle(.gray600)
                        .lineLimit(1)

                    // 거리는 검색 결과 카드에만 있는 요소입니다. 지도 영역 조회 목록은 시안에 거리가 없어 두지 않습니다.
                    if store.isSearchResultPresented, let distance = photoBooth.nearbyDistance {
                        Rectangle()
                            .fill(.gray100)
                            .frame(width: 1, height: 10)

                        Text(distance.distanceString)
                            .nekiFont(.body14SemiBold)
                            .foregroundStyle(.gray700)
                            .fixedSize()
                    }
                }
            }
            
            Spacer()
            
            Button {
                handleFavoriteButtonTap(photoBooth)
            } label: {
                Image(isFavoritePresented(for: photoBooth) ? .iconHeart28Fill : .iconHeart28Gray)
            }
            .buttonStyle(.plain)
            .disabled(pendingFavoriteRemovalIDs.contains(photoBooth.id))
        }
        .contentShape(.rect)
        .onTapGesture { store.send(.didTapBooth(photoBooth)) }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    func unavailableView(_ message: String) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Image(.iconPlace)
            
            Text(message)
                .nekiFont(.body16Medium)
                .foregroundStyle(.gray500)
        }
        .frame(maxWidth: .infinity, minHeight: 375, alignment: .center)
    }

    func isFavoritePresented(for photoBooth: PhotoBooth) -> Bool {
        favoriteButtonOverrides[photoBooth.id] ?? photoBooth.isFavorite
    }

    func handleFavoriteButtonTap(_ photoBooth: PhotoBooth) {
        guard photoBooth.isFavorite else {
            store.send(.didTapFavorite(photoBooth), animation: Self.FavoriteRemovalEffect.animation)
            return
        }

        favoriteButtonOverrides[photoBooth.id] = false

        guard store.selectedTab == .favorite else {
            store.send(.didTapFavorite(photoBooth), animation: Self.FavoriteRemovalEffect.animation)
            resetFavoriteButtonOverride(photoBooth.id, after: Self.FavoriteRemovalEffect.overrideResetDelay)
            return
        }

        guard pendingFavoriteRemovalIDs.contains(photoBooth.id) == false else { return }
        if favoriteRemovalReferenceBooths.isEmpty {
            favoriteRemovalReferenceBooths = store.visibleFavoriteBooths
        }
        if pendingFavoriteRemovalBooths[id: photoBooth.id] == nil {
            pendingFavoriteRemovalBooths.append(photoBooth)
        }
        pendingFavoriteRemovalIDs.insert(photoBooth.id)
        store.send(.didTapFavorite(photoBooth), animation: Self.FavoriteRemovalEffect.animation)
        delayedFavoriteTasks[photoBooth.id]?.cancel()
        delayedFavoriteTasks[photoBooth.id] = Task { @MainActor in
            try? await Task.sleep(for: Self.FavoriteRemovalEffect.delay)
            guard Task.isCancelled == false else { return }
            withAnimation(Self.FavoriteRemovalEffect.animation) {
                pendingFavoriteRemovalIDs.remove(photoBooth.id)
                pendingFavoriteRemovalBooths.remove(id: photoBooth.id)
                favoriteButtonOverrides[photoBooth.id] = nil
                if pendingFavoriteRemovalIDs.isEmpty {
                    favoriteRemovalReferenceBooths.removeAll()
                }
            }
            delayedFavoriteTasks[photoBooth.id] = nil
        }
    }

    func resetFavoriteButtonOverride(_ id: PhotoBooth.ID, after delay: Duration) {
        delayedFavoriteTasks[id]?.cancel()
        delayedFavoriteTasks[id] = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard Task.isCancelled == false else { return }
            favoriteButtonOverrides[id] = nil
            delayedFavoriteTasks[id] = nil
        }
    }

    var displayedFavoriteBooths: [PhotoBooth] {
        guard pendingFavoriteRemovalIDs.isEmpty == false else { return Array(store.visibleFavoriteBooths) }

        let referenceBooths = favoriteRemovalReferenceBooths.isEmpty
            ? store.visibleFavoriteBooths
            : favoriteRemovalReferenceBooths
        var displayedBooths: [PhotoBooth] = []

        referenceBooths.forEach { photoBooth in
            if let visibleBooth = store.visibleFavoriteBooths[id: photoBooth.id] {
                displayedBooths.append(visibleBooth)
            } else if pendingFavoriteRemovalIDs.contains(photoBooth.id),
                      let pendingBooth = pendingFavoriteRemovalBooths[id: photoBooth.id] {
                displayedBooths.append(pendingBooth)
            }
        }

        store.visibleFavoriteBooths.forEach { photoBooth in
            if referenceBooths[id: photoBooth.id] == nil { displayedBooths.append(photoBooth) }
        }

        return displayedBooths
    }

    var displayedFavoriteBoothIDs: [PhotoBooth.ID] {
        displayedFavoriteBooths.map(\.id)
    }

    func updateVerticalScrollTopState(_ offset: CGFloat) {
        let isAtTop = offset >= Constants.scrollTopThreshold
        guard isVerticalScrollAtTop != isAtTop else { return }
        isVerticalScrollAtTop = isAtTop
        sheetScrollStateHandler.updateIsAtTop(isAtTop)
    }
}


// MARK: - SearchResultBrandFilterChipStyle

/// 검색 결과 위에 놓이는 외곽선 형태의 드롭다운 칩입니다.
///
/// 디자인 시스템의 `NekiChipButtonStyle`(회색 채움, 20pt 화살표)과 달리 흰 바탕에 1.2pt 테두리와 24pt 화살표를 씁니다.
/// 브랜드가 하나라도 골라져 있으면 채워진 모양으로 바뀌어 필터가 걸려 있음을 알립니다.
private struct SearchResultBrandFilterChipStyle: ButtonStyle {
    let isHighlighted: Bool

    private enum Constants {
        static let borderWidth: CGFloat = 1.2
        static let leadingPadding: CGFloat = 12
        static let trailingPadding: CGFloat = 9
        static let verticalPadding: CGFloat = 6
        static let pressedOpacity: Double = 0.6
    }

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: .zero) {
            configuration.label
                .nekiFont(.body14SemiBold)
                .foregroundStyle(isHighlighted ? .white : .gray600)

            Image(.iconChevronDown)
                .renderingMode(.template)
                .foregroundStyle(isHighlighted ? .white : .gray400)
        }
        .padding(.leading, Constants.leadingPadding)
        .padding(.trailing, Constants.trailingPadding)
        .padding(.vertical, Constants.verticalPadding)
        .background { Capsule().fill(isHighlighted ? .gray800 : .white) }
        .overlay { Capsule().strokeBorder(isHighlighted ? .gray800 : .gray50, lineWidth: Constants.borderWidth) }
        .opacity(configuration.isPressed ? Constants.pressedOpacity : 1)
    }
}


// MARK: - NearPhotoBoothListScrollOffsetPreferenceKey

private struct NearPhotoBoothListScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = nextValue()
    }
}


// MARK: - Preview

#Preview("검색 결과") {
    @Previewable @State var detent: NekiSheetDetent = .large

    Color.gray50
        .ignoresSafeArea()
        .nekiSheet(selection: $detent) {
            NearPhotoBoothListSheet(
                store: PhotoBoothListPreviewData.store(PhotoBoothListPreviewData.searchResultState())
            )
        } controllers: {
            EmptyView()
        }
}

#Preview("검색 결과 · 브랜드 선택") {
    @Previewable @State var detent: NekiSheetDetent = .large

    Color.gray50
        .ignoresSafeArea()
        .nekiSheet(selection: $detent) {
            NearPhotoBoothListSheet(
                store: PhotoBoothListPreviewData.store(
                    PhotoBoothListPreviewData.searchResultState(
                        selecting: [PhotoBoothListPreviewData.brands[1], PhotoBoothListPreviewData.brands[4]]
                    )
                )
            )
        } controllers: {
            EmptyView()
        }
}

#Preview("지도 영역 목록") {
    @Previewable @State var detent: NekiSheetDetent = .large

    Color.gray50
        .ignoresSafeArea()
        .nekiSheet(selection: $detent) {
            NearPhotoBoothListSheet(
                store: PhotoBoothListPreviewData.store(PhotoBoothListPreviewData.nearbyState())
            )
        } controllers: {
            EmptyView()
        }
}
