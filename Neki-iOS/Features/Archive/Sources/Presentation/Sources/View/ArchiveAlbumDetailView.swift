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
    @State var deleteAlbumSheetPresented: Bool = false
    @State var editAlbumNameSheetPresented: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                
                if store.filteredAlbumPhotos.isEmpty {
                    ArchiveEmptyView(description: "아직 등록된 사진이 없어요\n새로운 사진을 등록하고 앨범에 추가해보세요!")
                        .padding(.bottom, 54)
                } else {
                    masonryView
                }
            }
            
            if store.showDropDownMenu && !store.isSelectionMode {
                dropDownButton
                    .padding(.top, 47)
                    .padding(.trailing, 20)
            }
            
            if store.isSelectionMode {
                VStack {
                    Spacer()
                    ArchiveImageFooter(
                        style: .selection,
                        isEnabled: store.hasSelectedItems,
                        onDownload: { store.send(.onTapDownloadButton) },
                        onDelete: { deleteAlbumSheetPresented = true },
                        onDuplicate: {
                            // TODO: 사진 복제 액션
                        },
                        onMove: {
                            // TODO: 사진 이동 액션
                        }
                    )
                }
            }
            
            if store.isLoading {
                LoadingView(message: "사진을 업로드하고 있어요.")
            }
        }
        .task { await store.send(.onAppear).finish() }
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
        .sheet(isPresented: $editAlbumNameSheetPresented) {
            ArchiveAlbumInputSheet(
                style: .edit,
                text: $store.newAlbumTitle,
                errorMessage: store.albumTitleErrorMessage,
                isConfirmEnabled: store.isConfirmButtonEnabled,
                onCancel: {
                    store.send(.onTapCancelEditAlbum)
                    withAnimation {
                        editAlbumNameSheetPresented = false
                    }
                },
                onConfirm: {
                    store.send(.onTapConfirmEditAlbum)
                    withAnimation {
                        editAlbumNameSheetPresented = false
                    }
                }
            )
            .presentationDetents([.height(266)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .background(.white)
        
    }
}

private extension ArchiveAlbumDetailView {
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
                            store.send(.toggleDropDownMenu)
                        } label: {
                            Image(.iconEllipsis)
                        }
                    }
                }
            }
            
            // 수정되는 모습이 바로바로 보여서 이렇게 해뒀는데, QA 후 별로라는 의견 나오면 별도 title로 관리
            Text(store.newAlbumTitle)
                .nekiFont(.title18SemiBold)
                .foregroundStyle(.gray900)
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
    }
    
    var dropDownButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                store.send(.onTapSelectButton)
            } label: {
                Text("사진 선택")
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
            }
            .frame(width: 120, height: 34, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())

            NekiImagePicker(store: store.scope(state: \.imagePicker, action: \.imagePicker)) {
                Text("사진 추가")
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
            }
            .frame(width: 120, height: 34, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())

            Button {
                store.send(.closeDropDownMenu)
                editAlbumNameSheetPresented = true
            } label: {
                Text("앨범 이름 변경")
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
            }
            .frame(width: 120, height: 34, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 8)
        .frame(width: 120, alignment: .topLeading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 2.5, x: 0, y: 0)
    }
    
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
                    isSelected: store.selectedIDs.contains(item.id),
                    onTapFavorite: { store.send(.onTapFavorite(item: item)) }
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
                    if store.showDropDownMenu { store.send(.closeDropDownMenu) }
                    lastDragPoint = currentPoint
                }
                .onEnded { _ in lastDragPoint = 0 }
        )
    }
}
