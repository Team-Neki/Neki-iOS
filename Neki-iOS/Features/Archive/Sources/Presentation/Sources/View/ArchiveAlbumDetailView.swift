//
//  ArchiveAlbumDetailView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveAlbumDetailView: View {
    @Bindable var store: StoreOf<ArchiveAlbumDetailFeature>
    
    @State private var isFilterBarVisible: Bool = true
    @State private var lastDragPoint: CGFloat = 0
    @State var showDropDownMenu: Bool = false
    @State var deleteAlbumSheetPresented: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            if store.photos.isEmpty {
                ArchiveEmptyView()
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
                        onDelete: { deleteAlbumSheetPresented = true }
                    )
                }
            }
        }
        .nekiToolbar(
            left: .back(action: { store.send(.onTapBackButton) }),
            center: .text(store.album.title),
            right: store.photos.isEmpty ? .none : store.isSelectionMode ?
                .text("취소", action: { store.send(.onTapCancelSelectButton) }) :
                    .text("선택", action: { store.send(.onTapSelectButton) })
        )
        .sheet(isPresented: $deleteAlbumSheetPresented) {
            ArchiveDeleteSheet(
                selectedOption: $store.deleteOption,
                title: "사진을 삭제하시겠어요?",
                firstOption: (.fromAlbumOnly, "앨범에서만 제거"),
                secondOption: (.everywhere, "모든 위치에서 사진 제거"),
                onCancel: {
                    deleteAlbumSheetPresented = false
                },
                onConfirm: {
                    store.send(.onTapDeleteButton)
                    deleteAlbumSheetPresented = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationCornerRadius(20)
        }
        .task {
            await store.send(.onAppear).finish()
        }
        .background(.white)
    }
}

private extension ArchiveAlbumDetailView {
    @ViewBuilder
    var masonryView: some View {
        ScrollView {
            MasonryGridView(
                items: Array(store.filteredAlbumPhotos),
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
                    if item == store.filteredAlbumPhotos.last {
                        store.send(.loadMorePhotos)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 76)
        }
        .scrollIndicators(.never)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    let currentPoint = value.translation.height
                    let diff = currentPoint - lastDragPoint
                    withAnimation(.smooth) {
                        isFilterBarVisible = diff < 0 ? false : true
                    }
                    if showDropDownMenu { showDropDownMenu = false }
                    lastDragPoint = currentPoint
                }
                .onEnded { _ in lastDragPoint = 0 }
        )
    }
}
