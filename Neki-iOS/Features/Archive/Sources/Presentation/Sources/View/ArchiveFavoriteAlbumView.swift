//
//  ArchiveFavoriteAlbumView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveFavoriteAlbumView: View {
    @Bindable var store: StoreOf<ArchiveFavoriteAlbumFeature>

    @State var showDeleteAlert: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            if store.filteredItems.isEmpty {
                ArchiveEmptyView()
            } else {
                masonryView
            }
            
            if store.isSelectionMode {
                VStack {
                    Spacer()
                    ArchiveImageFooter(
                        isEnabled: store.hasSelectedItems,
                        onDownload: { store.send(.onTapDownloadButton) },
                        onDelete: { showDeleteAlert = true }
                    )
                }
            }
        }
        .nekiToolbar(
            left: .back(action: { store.send(.onTapBackButton) }),
            center: .text(store.album.title),
            right: store.filteredItems.isEmpty ? .none : store.isSelectionMode ?
                .text("취소", action: { store.send(.onTapCancelSelectButton) }) :
                .text("선택", action: { store.send(.onTapSelectButton) })
        )
        .nekiAlert(
            isPresented: $showDeleteAlert,
            style: .cancelable,
            titleMessage: "사진을 삭제하시겠어요?",
            subTitleMessage: "이 작업은 실행취소할 수 없어요",
            confirmText: "삭제하기",
            cancelText: "취소",
            onConfirm: {
                store.send(.onTapDeleteButton)
                showDeleteAlert = false
            },
            onCancel: {
                showDeleteAlert = false
            }
        )
        .background(.white)
    }
}

private extension ArchiveFavoriteAlbumView {
    @ViewBuilder
    var masonryView: some View {
        ScrollView {
            MasonryGridView(
                items: Array(store.filteredItems),
                columns: 2
            ) { item in
                ArchiveImageCard(
                    item: item,
                    isSelectionMode: store.isSelectionMode,
                    isSelected: store.selectedIDs.contains(item.id)
                )
                .onTapGesture {
                    store.send(.imageTapped(item))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 76)
        }
        .scrollIndicators(.never)
    }
}
