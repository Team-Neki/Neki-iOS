//
//  ArchiveAllAlbumsView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/20/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveAllAlbumsView: View {
    @Bindable var store: StoreOf<ArchiveAllAlbumsFeature>
    
    @State var addAlbumSheetPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(store.albums) { album in
                        AlbumRowTile(album: album)
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.top, 8)
                .padding(.horizontal, 20)
            }
        }
        .nekiToolbar(left: .back(action: { store.send(.onTapBackButton) }),
                     center: .text("모든 앨범"),
                     right: .both([.text("생성", action: { addAlbumSheetPresented = true }), .icon(.iconEllipsis, action: {})]))
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
    }
}
