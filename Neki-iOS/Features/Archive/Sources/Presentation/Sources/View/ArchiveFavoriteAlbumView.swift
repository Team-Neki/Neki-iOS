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
            if store.photos.count == 0 {
                ArchiveEmptyView(description: "아직 등록된 사진이 없어요\n새로운 사진을 등록하고 앨범에 추가해보세요!")
                    .padding(.bottom, 54)
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
        .task { await store.send(.onAppear).finish() }
        .nekiToolbar(
            left: { NekiToolBar.back(action: { store.send(.onTapBackButton) }) },
            center: { NekiToolBar.textCenter(store.album.title) },
            right: {
                if store.photos.isEmpty == false {
                    store.isSelectionMode ? NekiToolBar.textRight("취소", action: { store.send(.onTapCancelSelectButton) }) : NekiToolBar.textRight("선택", action: { store.send(.onTapSelectButton) })
                }
            }
        )
        .nekiAlert(
            isPresented: $showDeleteAlert,
            style: .cancelable,
            title: "사진을 삭제하시겠어요?",
            subtitle: "이 작업은 실행취소할 수 없어요",
            confirmText: "삭제하기",
            cancelText: "취소",
            hasIcon: true,
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
                items: Array(store.photos),
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
                .onAppear {
                    if item == store.photos.last {
                        store.send(.loadMorePhotos)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 76)
        }
        .scrollIndicators(.never)
    }
}
