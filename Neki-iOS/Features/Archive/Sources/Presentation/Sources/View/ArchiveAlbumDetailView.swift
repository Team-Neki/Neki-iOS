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
            if store.filteredAlbumPhotos.isEmpty {
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
                        onDelete: { deleteAlbumSheetPresented = true }
                    )
                }
            }
        }
        .task { await store.send(.onAppear).finish() }
        .nekiToolbar(
            left: { NekiToolBar.back { store.send(.onTapBackButton) } },
            center: { NekiToolBar.textCenter(store.album.title) },
            right: {
                if store.filteredAlbumPhotos.count != 0 {
                    store.isSelectionMode ?
                    NekiToolBar.textRight("취소") { store.send(.onTapCancelSelectButton) } :
                    NekiToolBar.textRight("선택") { store.send(.onTapSelectButton) }
                }
            }
        )
        .sheet(isPresented: $deleteAlbumSheetPresented) {
            ArchiveDeleteSheet<ArchivePhotoDeleteOption>(
                initialOption: .fromAlbumOnly,
                title: "사진을 삭제하시겠어요?",
                firstOption: (.fromAlbumOnly, "앨범에서만 제거"),
                secondOption: (.everywhere, "모든 위치에서 사진 제거"),
                onCancel: {
                    deleteAlbumSheetPresented = false
                },
                onConfirm: { selectedOption in
                    store.send(.onTapDeleteButton(option: selectedOption))
                    deleteAlbumSheetPresented = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationCornerRadius(20)
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
