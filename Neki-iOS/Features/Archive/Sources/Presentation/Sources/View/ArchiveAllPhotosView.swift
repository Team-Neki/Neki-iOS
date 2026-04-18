//
//  ArchiveAllPhotosView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/19/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveAllPhotosView: View {
    @Bindable var store: StoreOf<ArchiveAllPhotosFeature>
    
    @State private var isFilterBarVisible: Bool = true
    @State private var lastDragPoint: CGFloat = 0
    @State var showDropDownMenu: Bool = false
    @State var showDeleteAlert: Bool = false
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .background(.white)
                .zIndex(9)
            
            ZStack(alignment: .top) {
                masonryView
                
                if !store.isSelectionMode {
                    filterBar
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .padding(.bottom, 12)
                        .background(.white)
                        .offset(y: isFilterBarVisible ? 0 : -100)
                }
                
                if store.isSelectionMode {
                    VStack {
                        Spacer()
                        ArchiveImageFooter(
                            style: .selection,
                            isEnabled: store.hasSelectedItems,
                            onDownload: { store.send(.onTapDownloadButton) },
                            onDelete: { showDeleteAlert = true },
                            onDuplicate: { store.send(.onTapDuplicateButton) },
                            onMove: nil
                        )
                    }
                }
                
                if store.isLoading {
                    LoadingView(message: "요청을 처리하고 있어요.")
                }
                
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.photos)
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
        .task {
            await store.send(.onAppear).finish()
        }
        .fullScreenCover(item: $store.scope(state: \.albumSelection, action: \.albumSelection)) { selectionStore in
            AlbumSelectionView(store: selectionStore)
        }
    }
}

private extension ArchiveAllPhotosView {
    @ViewBuilder
    var header: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center, spacing: 0) {
                Button {
                    store.send(.onTapBackButton)
                } label: {
                    Image(.iconChevronLeft)
                }
                
                Spacer()
                
                HStack(alignment: .center, spacing: 12) {
                    if store.isSelectionMode {
                        Button {
                            store.send(.onTapCancelSelectButton)
                        } label: {
                            Text("취소")
                                .nekiFont(.body16SemiBold)
                                .foregroundStyle(.gray800)
                        }
                    } else {
                        Button {
                            store.send(.onTapSelectButton)
                        } label: {
                            Text("선택")
                                .nekiFont(.body16SemiBold)
                                .foregroundStyle(.primary500)
                        }
                    }
                }
            }
            
            Text("모든 사진")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    var masonryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MasonryGridView(
                    items: Array(store.filteredItems),
                    columns: 2,
                ) { item in
                    ArchiveImageCard(
                        item: item,
                        isSelectionMode: store.isSelectionMode,
                        isSelected: store.selectedIDs.contains(item.id),
                        onTapFavorite: { store.send(.onTapFavorite(item: item)) }
                    )
                    .onTapGesture {
                        store.send(.imageTapped(item))
                    }
                    .onAppear {
                        if item == store.filteredItems.last {
                            store.send(.loadMorePhotos)
                        }
                    }
                }
                
                if store.isFetchingPhotos && !store.photos.isEmpty {
                    ProgressView()
                        .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, store.isSelectionMode ? 8 : 54)
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
                .onEnded {_ in
                    lastDragPoint = 0
                }
        )
    }
    
    @ViewBuilder
    var filterBar: some View {
        HStack(alignment: .center, spacing: 6) {
            Button(store.state.selectedSortedTime) {
                withAnimation { showDropDownMenu.toggle() }
            }
            .buttonStyle(
                .nekiChip(
                    isHighlighted: false,
                    shape: .capsule,
                    style: .dropdown
                )
            )
            .overlay(alignment: .top) {
                if showDropDownMenu {
                    dropDownMenu
                        .padding(.top, 43)
                        .padding(.leading, 15)
                }
            }
            
            Button("즐겨찾는") {
                store.send(.onTapFavoriteButton)
                if showDropDownMenu { showDropDownMenu = false }
            }
            .buttonStyle(
                .nekiChip(
                    isHighlighted: store.state.isSelectedFavorite,
                    shape: .capsule,
                    style: .normal
                )
            )
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var dropDownMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            dropDownMenuButton(title: "최신순") {
                withAnimation { showDropDownMenu = false }
                store.send(.onTapFilterNewest)
            }
            
            dropDownMenuButton(title: "오래된순") {
                withAnimation { showDropDownMenu = false }
                store.send(.onTapFilterOldest)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 96, height: 72)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 2.5, x: 0, y: 0)
    }
    
    func dropDownMenuButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray900)
                .frame(height: 20)
        }
        .buttonStyle(MenuButtonStyle())
    }
    
    struct MenuButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.vertical, 5)
                .background(configuration.isPressed ? .gray50 : .white)
        }
    }
}
