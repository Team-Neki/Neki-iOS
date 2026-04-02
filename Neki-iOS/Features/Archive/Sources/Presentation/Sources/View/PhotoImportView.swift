//
//  PhotoImportView.swift
//  Neki-iOS
//
//  Created by OneTen on 4/3/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct PhotoImportView: View {
    @Bindable var store: StoreOf<PhotoImportFeature>
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header
                    .padding(.top, 16)
                
                if store.isFetchingPhotos && store.photos.isEmpty {
                    LoadingView(message: "사진을 불러오는 중이에요")
                } else if store.photos.isEmpty {
                    Spacer()
                    ArchiveEmptyView(description: "아직 등록된 사진이 없어요")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(store.photos) { item in
                                imageCell(for: item)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                Button {
                    store.send(.tapUpload)
                } label: {
                    Text("\(store.uploadCount)장 업로드")
                }
                .buttonStyle(.nekiCTA(.primary))
                .disabled(!store.isUploadEnabled)
                .padding(.horizontal, 20)
            }
            
            if store.isDropdownOpen {
                dropDownMenu
                    .padding(.top, 48)
                    .padding(.leading, 20)
            }
            
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await store.send(.onAppear).finish()
        }
    }
}

extension PhotoImportView {
    private var header: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center) {
                Button {
                    store.send(.toggleDropdown)
                } label: {
                    HStack(spacing: 4) {
                        Text(store.selectedAlbum?.title ?? "전체 사진")
                            .nekiFont(.title20SemiBold)
                            .foregroundStyle(.gray900)
                        
                        Image(.iconChevronDown)
                            .renderingMode(.template)
                            .foregroundStyle(.gray500)
                            .rotationEffect(.degrees(store.isDropdownOpen ? 180 : 0))
                    }
                }
                
                Spacer()
                
                Button {
                    store.send(.tapClose)
                } label: {
                    Image(.iconXmarkBlack)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 54)
    }
    
    private var dropDownMenu: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 전체 사진
                Button {
                    store.send(.selectAlbum(nil))
                } label: {
                    HStack {
                        Text("전체 사진")
                            .nekiFont(.body16Medium)
                            .foregroundStyle(.gray900)
                        Spacer()
                    }
                }
                .frame(width: 160, height: 34, alignment: .leading)
                
                // 앨범 목록
                ForEach(store.albums) { album in
                    Button {
                        store.send(.selectAlbum(album))
                    } label: {
                        HStack {
                            Text(album.title)
                                .nekiFont(.body16Medium)
                                .foregroundStyle(.gray900)
                                .lineLimit(1)
                            Text("\(album.count)")
                                .nekiFont(.caption12Medium)
                                .foregroundStyle(.gray300)
                            Spacer()
                        }
                    }
                    .frame(width: 160, height: 34, alignment: .leading)
                    
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2.5)
            .frame(width: 160)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func imageCell(for item: ArchiveImageItem) -> some View {
        let isSelected = store.selectedIDs.contains(item.id)
        
        ZStack(alignment: .topTrailing) {
            KFImage(item.imageURL)
                .resizable()
                .placeholder { Color.gray.opacity(0.1) }
                .aspectRatio(1, contentMode: .fit)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 145, maxHeight: .infinity)
                .clipped()
                .overlay(
                    Rectangle()
                        .strokeBorder(isSelected ? Color.primary400 : Color.clear, lineWidth: 2)
                )
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .primary400 : .white)
                .background(
                    Circle()
                        .fill(isSelected ? .white : .black.opacity(0.2))
                        .frame(width: 24, height: 24)
                )
                .padding(6)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.toggleSelection(item.id))
        }
    }
}
