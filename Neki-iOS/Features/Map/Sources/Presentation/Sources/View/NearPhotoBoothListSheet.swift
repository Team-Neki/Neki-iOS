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
        .coordinateSpace(name: Constants.verticalScrollCoordinateSpaceName)
        .onPreferenceChange(NearPhotoBoothListScrollOffsetPreferenceKey.self) { offset in
            updateVerticalScrollTopState(offset)
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
                    ForEach(store.displayedBrands, id: \.self) { brand in
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(photoBooth.brand.name)
                    .nekiFont(.title18SemiBold)
                    .foregroundStyle(.gray900)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(photoBooth.name)
                        .nekiFont(.body14Medium)
                        .foregroundStyle(.gray600)
                        .lineLimit(1)
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
