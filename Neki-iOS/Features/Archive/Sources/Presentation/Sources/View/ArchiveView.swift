//
//  ArchiveView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct ArchiveView: View {
    
    @State var addAlbumSheetPresented: Bool = false
    @State var showScrollToTopButton: Bool = false
    @State private var maximumDisplayHeight: CGFloat = .infinity
    
    @Bindable var store: StoreOf<ArchiveFeature>
    
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .zIndex(9)
                
                ScrollViewReader { proxy in
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Color.clear
                                    .frame(height: 0)
                                    .id("SCROLL_TO_TOP")
                                
                                albumSection
                                    .padding(.bottom, 28)
                                
                                recentPhotoSection
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetKey.self,
                                            value: geo.frame(in: .named("ARCHIVE_SCROLL")).minY
                                        )
                                }
                            )
                        }
                        .scrollIndicators(.never)
                        .coordinateSpace(name: "ARCHIVE_SCROLL")
                        
                        if showScrollToTopButton {
                            Button {
                                withAnimation {
                                    proxy.scrollTo("SCROLL_TO_TOP", anchor: .top)
                                }
                            } label: {
                                Image(.btnFloatingArchive)
                            }
                            .padding()
                            .padding(.bottom, 52)
                        }
                    }
                    .onPreferenceChange(ScrollOffsetKey.self) { value in
                        let shouldShowButton = value < -20
                        guard showScrollToTopButton != shouldShowButton else { return }
                        withAnimation { showScrollToTopButton = shouldShowButton }
                    }
                }
            }
            
            // 툴팁이 보여져 있을 경우 화면 어디든 누르면 사라지게
            if store.showTooltip {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.showTooltip = false
                    }
            }
            
        }
        .nekiLoading(
            isPresented: isBlockingLoading,
            message: blockingLoadingMessage
        )
        .fullScreenCover(item: $store.scope(state: \.selectUploadAlbum, action: \.selectUploadAlbum)) { store in
            SelectUploadAlbumView(store: store)
                .presentationBackground(.clear)
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            guard height > .zero, maximumDisplayHeight != height else { return }
            maximumDisplayHeight = height
        }
        .sheet(isPresented: $addAlbumSheetPresented) {
            ArchiveAlbumInputSheet(
                style: .add,
                text: $store.newAlbumTitle,
                errorMessage: store.albumTitleErrorMessage,
                isConfirmEnabled: store.isConfirmButtonEnabled,
                onCancel: {
                    store.send(.onTapCancelAddAlbum)
                    withAnimation {
                        addAlbumSheetPresented = false
                    }
                },
                onConfirm: {
                    store.send(.onTapConfirmAddAlbum)
                    withAnimation {
                        addAlbumSheetPresented = false
                    }
                }
            )
            .presentationDetents([.height(266)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .task {
            await store.send(.onAppear).finish()
        }
    }

    private var isBlockingLoading: Bool {
        store.isLoading || store.isInitialFetchingPhotos
    }

    private var blockingLoadingMessage: String {
        store.isLoading ? "사진을 업로드하고 있어요." : "사진을 불러오고 있어요."
    }
}


// MARK: - Subviews

private extension ArchiveView {
    var header: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(.iconLogo)
            
            Spacer()
            
            HStack(alignment: .center, spacing: 12) {
                Button {
                    store.send(.onTapQRScan)
                } label: {
                    Image(.iconQrCode)
                }
                .nekiTooltip(
                    isPresented: $store.showTooltip,
                    "QR스캔으로 빠르게 네컷을 추가해보세요!",
                    position: .bottom,
                    style: .dark,
                    showDismiss: false
                )
                
                Button {
                    store.send(.notificationButtonTapped)
                } label: {
                    Image(.iconBellFill)
                }
            }
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
    }
    
    var albumSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Text("앨범")
                    .nekiFont(.title20Bold)
                    .foregroundStyle(.gray900)
                
                Spacer()
                
                Button {
                    store.send(.onTapAllAlbums)
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        Text("전체 앨범")
                            .nekiFont(.body14Regular)
                            .foregroundStyle(.gray500)
                        
                        Image(.iconChevronRight)
                    }
                }
            }
            .padding(.bottom, 12)
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.previewAlbums, id: \.id) { album in
                        Button {
                            store.send(.albumTapped(album))
                        } label: {
                            AlbumCard(album: album)
                        }
                    }
                    
                    Button {
                        withAnimation {
                            addAlbumSheetPresented = true
                        }
                    } label: {
                        VStack(alignment: .center, spacing: 8) {
                            Image(.iconPlusRed)
                            
                            Text("새 앨범 추가")
                                .nekiFont(.body14Medium)
                        }
                        .frame(width: 124, height: 166)
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(content: {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.primary400 , style: StrokeStyle(lineWidth: 2, lineCap: .round,
                                                                           dash: [5, 5], dashPhase: 0))
                    })
                    
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    var recentPhotoSection: some View {
        let lastPhotoID = store.photos.last?.id

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("최근 사진")
                    .nekiFont(.title20Bold)
                    .foregroundStyle(.gray900)
                
                Spacer()
                
                Button {
                    store.send(.onTapAllPhotos)
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        Text("모든 사진")
                            .nekiFont(.body14Regular)
                            .foregroundStyle(.gray500)
                        
                        Image(.iconChevronRight)
                    }
                }
            }
            .padding(.bottom, 12)
            
            if store.photos.isEmpty {
                ArchiveEmptyView(description: "아직 등록된 사진이 없어요\n찍은 네컷을 네키에 저장해보세요!")
                    .padding(.top, 70)
            } else {
                MasonryGridView(
                    items: Array(store.photos),
                    estimatedHeight: \.masonryEstimatedHeight
                ) { item in
                    ArchiveImageCard(item: item, onTapFavorite: { store.send(.onTapFavorite(item: item)) })
                        .onTapGesture {
                            store.send(.imageTapped(item))
                        }
                        .onAppear {
                            guard item.id == lastPhotoID else { return }
                            store.send(.loadMorePhotos)
                        }
                }
                .padding(.bottom, 76)
                .nekiImageMaximumDisplayHeight(maximumDisplayHeight)
            }
            
            if store.isFetchingPhotos && !store.photos.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 20)
    }
}

private extension ArchiveView {
    struct ScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value += nextValue()
        }
    }
}

#Preview {
    ArchiveCoordinatorView(store: .init(initialState: ArchiveCoordinator.State(), reducer: { ArchiveCoordinator() }))
}
