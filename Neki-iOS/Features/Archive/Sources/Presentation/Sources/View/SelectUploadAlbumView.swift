//
//  SelectUploadAlbumView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct SelectUploadAlbumView: View {
    @Bindable var store: StoreOf<SelectUploadAlbumFeature>
    
    var body: some View {
        ZStack {
            if store.viewMode == .prompt {
                Color.gray900.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                Color.white
                    .ignoresSafeArea()
            }
            
            Group {
                switch store.viewMode {
                case .prompt:
                    promptPopupView
                        .transition(.opacity)
                    
                case .albumList:
                    NavigationStack {
                        albumListView
                            .toolbar(.hidden, for: .navigationBar)
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeInOut, value: store.viewMode)
    }
}

// MARK: - Subviews

private extension SelectUploadAlbumView {
    var promptPopupView: some View {
        VStack(alignment: .center, spacing: 4) {
            Button {
                store.send(.tapUploadWithoutAlbum)
            } label: {
                Text("앨범 없이 업로드하기")
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray800)
            }
            .padding(.vertical, 14)
            
            Divider()
            
            Button {
                store.send(.tapSelectAlbumAndUpload)
            } label: {
                HStack {
                    Text("앨범 선택 후 업로드하기")
                        .nekiFont(.body16SemiBold)
                        .foregroundStyle(.gray800)
                }
                .padding(.vertical, 14)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 33)
    }
    
    var albumListView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                HStack(alignment: .center, spacing: 0) {
                    Button {
                        store.send(.tapBackToPrompt)
                    } label: {
                        Image(.iconChevronLeft)
                    }
                    
                    Spacer()
                    
                    Button {
                        store.send(.tapConfirmUpload)
                    } label: {
                        Text("\(store.uploadedImageIds.count)장 업로드")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(store.selectedAlbumId == nil ? .gray200 : .primary500)
                    }
                    .disabled(store.selectedAlbumId == nil)
                }
                .frame(height: 54)
                .padding(.horizontal, 20)
                
                Text("모든 앨범")
                    .nekiFont(.title18SemiBold)
                    .foregroundStyle(.gray900)
            }
            .frame(height: 54)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(store.albums) { album in
                        AlbumRowTile(
                            album: album,
                            isSelectMode: true,
                            isDeleteMode: false,
                            isSelected: store.selectedAlbumId == album.id
                        )
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.tapAlbum(album))
                        }
                    }
                }
            }
            .padding(.top, 8)
            
        }
        
    }
}
