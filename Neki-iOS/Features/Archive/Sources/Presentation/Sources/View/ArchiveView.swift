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
                        withAnimation {
                            showScrollToTopButton = value < -20
                        }
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
            
//            if store.showDropDownMenu {
//                dropDownMenu
//                    .padding(.top, 46)
//                    .padding(.trailing, 16)
//            }
            
        }
        .sheet(isPresented: $addAlbumSheetPresented) {
            ArchiveAddAlbumSheet(
                text: $store.newAlbumTitle,
                errorMessage: store.albumTitleErrorMessage,
                isConfirmEnabled: store.isConfirmButtonEnabled,
                onCancel: {
                    store.send(.onTapCancelAddAlbum)
                    addAlbumSheetPresented = false
                },
                onConfirm: {
                    store.send(.onTapConfirmAddAlbum)
                    addAlbumSheetPresented = false
                }
            )
            .presentationDetents([.height(266)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .fullScreenCover(isPresented: $store.isLoading, content: {
            LoadingView(message: "사진을 업로드하고 있어요.")
        })
        .fullScreenCover(item: $store.scope(state: \.selectUploadAlbum, action: \.selectUploadAlbum)) { store in
            SelectUploadAlbumView(store: store)
                .presentationBackground(.clear)
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .task {
            await store.send(.onAppear).finish()
        }
        .onTapGesture {
            if store.showDropDownMenu {
                store.showDropDownMenu = false
            }
        }
    }
}


// MARK: - Subviews

private extension ArchiveView {
    var header: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(.iconLogo)
            
            Spacer()
            
//            HStack(alignment: .center, spacing: 12) {
//                Button {
//                    store.send(.toggleDropDownMenu)
//                } label: {
//                    Image(.iconPlusRed)
//                }
//                .nekiTooltip(
//                    isPresented: $store.showTooltip,
//                    "버튼을 눌러 네컷을 추가할 수 있어요",
//                    position: .bottom,
//                    style: .dark,
//                    showDismiss: false
//                )
                
//                Button {
//                    // TODO: - 알림 이벤트
//                } label: {
//                    Image(.iconBellFill)
//                }
//            }
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
    }
    
//    var dropDownMenu: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            dropDownMenuButton(title: "QR 인식", icon: .iconQrcodeScan) {
//                store.send(.onTapQRScan)
//            }
//            
//            NekiImagePicker(store: store.scope(state: \.imagePicker, action: \.imagePicker)) {
//                HStack(alignment: .center, spacing: 6) {
//                    Image(uiImage: .iconRoundAddPhotoAlternate)
//                    
//                    Text("갤러리에서 추가")
//                        .nekiFont(.body16Medium)
//                        .foregroundStyle(.gray900)
//                    
//                    Spacer()
//                }
//                .padding(.leading, 12)
//                .padding(.vertical, 5)
//                .frame(height: 34)
//                .contentShape(Rectangle())
//            }
//            
//            Divider()
//                .background(.gray50)
//                .padding(.vertical, 4)
//            
//            dropDownMenuButton(title: "새 앨범 추가", icon: .iconSolarFolderBold) {
//                addAlbumSheetPresented = true
//                store.send(.onTapCancelAddAlbum)
//            }
//        }
//        .padding(.vertical, 5)
//        .frame(width: 158, height: 130)
//        .background(.white)
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//        .shadow(color: .black.opacity(0.2), radius: 2.5, x: 0, y: 0)
//    }
    
    func dropDownMenuButton(
        title: String,
        icon: UIImage,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 6) {
                Image(uiImage: icon)
                
                Text(title)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
                
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.vertical, 5)
            .frame(height: 34)
        }
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
                    ForEach(store.albums) { album in
                        AlbumCard(album: album)
                            .onTapGesture {
                                store.send(.albumTapped(album))
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    var recentPhotoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    columns: 2
                ) { item in
                    ArchiveImageCard(item: item)
                        .onTapGesture {
                            store.send(.imageTapped(item))
                        }
                        .onAppear {
                            if item == store.photos.last {
                                store.send(.loadMorePhotos)
                            }
                        }
                }
                .padding(.bottom, 76)
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

// MARK: - 텍스트필드 글자 수 제한 extension

private extension TextField {
    ///글자 수 제한
    func maxLength(_ length: Int, text: Binding<String>) -> some View {
        self
            .onChange(of: text.wrappedValue) { _, newValue in
                if newValue.count > length {
                    text.wrappedValue = String(newValue.prefix(length))
                }
            }
    }
}


#Preview {
    ArchiveCoordinatorView(store: .init(initialState: ArchiveCoordinator.State(), reducer: { ArchiveCoordinator() }))
}
