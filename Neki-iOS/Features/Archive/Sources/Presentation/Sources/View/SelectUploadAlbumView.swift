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
            } else {
                Color.white
                    .ignoresSafeArea()
            }
            
            switch store.viewMode {
            case .prompt:
                promptPopupView
                
            case .albumList:
                albumListView
                    .transition(.move(edge: .trailing))
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
            NekiToolBar(
                leftItem: .back(action: {store.send(.tapBackToPrompt)}),
                centerItem: .text("모든 앨범"),
                rightItem: .text("\(store.uploadedImageIds.count)장 업로드",
                                 action: {store.send(.tapConfirmUpload)})
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(store.albums) { album in
                        AlbumRowTile(
                            album: album,
                            isSelectMode: true,
                            isSelected: store.selectedAlbumId == album.id
                        )
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.tapAlbum(album.id))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(Color.white)
    }
}
