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
    @State var showTooltip: Bool = true          // TODO: - UserDefault로 앱 첫 실행인지 여부 관리하기
    
    let store: StoreOf<ArchiveFeature>
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .zIndex(9)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        albumSection
                            .padding(.bottom, 28)
                        
                        recentPhotoSection
                    }
                }
                .scrollIndicators(.never)
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
                store.send(.onTapQRScan)
            }
            
            dropDownMenuButton(title: "갤러리에서 추가", icon: .iconRoundAddPhotoAlternate) {
                store.send(.onTapAddFromGallery)
            }
            
            Divider()
                .background(.gray50)
                .padding(.vertical, 4)
            
            dropDownMenuButton(title: "새 앨범 추가", icon: .iconSolarFolderBold) {
                store.send(.onTapAddNewAlbum)
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
