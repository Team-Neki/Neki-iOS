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
    
    @State var showDropDownMenu: Bool = false
    @State var showTooltip: Bool = false          // TODO: - UserDefault로 앱 첫 실행인지 여부 관리하기
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
            if showTooltip {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTooltip = false
                    }
            }
            
            if showDropDownMenu {
                dropDownMenu
                    .padding(.top, 42)
                    .padding(.trailing, 60)
            }
            
        }
        .sheet(isPresented: $addAlbumSheetPresented) {
            addAlbumSheet
                .presentationDetents([.height(266)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .task {
            await store.send(.onAppear).finish()
        }
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
                    withAnimation() {
                        showDropDownMenu.toggle()
                    }
                } label: {
                    Image(.iconPlusRed)
                }
                .nekiTooltip(
                    isPresented: $showTooltip,
                    "버튼을 눌러 네컷을 추가할 수 있어요",
                    position: .bottom,
                    style: .dark,
                    showDismiss: false
                )
                
                Button {
                    // TODO: - 알림 이벤트
                } label: {
                    Image(.iconBellFill)
                }
            }
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
    }
    
    var dropDownMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            dropDownMenuButton(title: "QR 인식", icon: .iconQrcodeScan) {
                withAnimation { showDropDownMenu = false }
                store.send(.onTapQRScan)
            }
            
            dropDownMenuButton(title: "갤러리에서 추가", icon: .iconRoundAddPhotoAlternate) {
                withAnimation { showDropDownMenu = false }
                store.send(.onTapAddFromGallery)
            }
            
            Divider()
                .background(.gray50)
                .padding(.vertical, 4)
            
            dropDownMenuButton(title: "새 앨범 추가", icon: .iconSolarFolderBold) {
                withAnimation { showDropDownMenu = false }
                addAlbumSheetPresented = true
                store.state.newAlbumTitle = ""
                store.albumTitleErrorMessage = nil
            }
        }
        .padding(.vertical, 5)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(content: {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.5), lineWidth: 1)
                .shadow(color: .gray.opacity(0.5), radius: 2)
        })
        .frame(width: 158, height: 130)
    }
    
    var addAlbumSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("새 앨범 추가")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
                .frame(height: 28)
                .padding(.top, 24)
                .padding(.bottom, 2)
            
            Text("네컷사진을 모을 앨범명을 입력하세요")
                .nekiFont(.body14Regular)
                .foregroundStyle(.gray700)
                .frame(height: 20)
                .padding(.bottom, 16)
            
            HStack(alignment: .center, spacing: 0) {
                TextField("앨범명을 입력하세요", text: $store.newAlbumTitle)
                    .maxLength(16, text: $store.newAlbumTitle)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
                    .frame(height: 50)
                
                Spacer()
                
                Text("\(store.newAlbumTitle.count)/16")
                    .nekiFont(.caption12Regular)
                    .foregroundStyle(.gray300)
            }
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(store.albumTitleErrorMessage != nil ? .primary600 : .gray75,
                            lineWidth: 1)
            )
            .padding(.bottom, 6)
            
            if let errorMessage = store.albumTitleErrorMessage {
                Text(errorMessage)
                    .frame(height: 16)
                    .nekiFont(.caption12Regular)
                    .foregroundStyle(.primary600)
                    .padding(.leading, 2)
                    .padding(.bottom, 18)
            } else {
                Color.clear
                    .frame(height: 16)
                    .padding(.bottom, 18)
            }
            
            GeometryReader { proxy in
                // 버튼 사이 간격
                let spacing: CGFloat = 12
                
                // 전체 너비에서 간격을 뺀 실제 버튼들의 너비
                let totalWidth = proxy.size.width - spacing
                
                // 비율 3:7
                let cancelWidth = totalWidth * 0.3
                let addWidth = totalWidth * 0.7
                
                HStack(alignment: .center, spacing: spacing) {
                    Button {
                        store.send(.onTapCancelAddAlbum)
                        addAlbumSheetPresented = false
                    } label: {
                        Text("취소")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.gray300)
                            .frame(width: cancelWidth)
                            .frame(height: 52)
                            .background(.gray50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        store.send(.onTapConfirmAddAlbum)
                        addAlbumSheetPresented = false
                    } label: {
                        Text("추가하기")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.white)
                            .frame(width: addWidth)
                            .frame(height: 52)
                            .background(store.isConfirmButtonEnabled ? .primary400 : .primary400.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!store.isConfirmButtonEnabled)
                }
            }
            .frame(height: 52)
            
        }
        .padding(.bottom, 34)
        .padding(.horizontal, 20)
        .background(.white)
    }
    
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
                    // TODO: - 전체 앨범 이동
                    print("전체 앨범 이동 클릭")
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
                        AlbumCardView(album: album)
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
            
            MasonryGridView(
                items: Array(store.photos),
                columns: 2
            ) { item in
                ArchiveImageView(item: item)
                    .onTapGesture {
                        store.send(.imageTapped(item))
                    }
            }
            .padding(.bottom, 76)
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


