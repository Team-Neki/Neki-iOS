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
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                
                if store.photos.count == 0 {
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
                        isEnabled: store.hasSelectedItems,
                        onDownload: { store.send(.onTapDownloadButton) },
                        onDelete: { showDeleteAlert = true }
                    )
                }
            }
            
        }
        .task { await store.send(.onAppear).finish() }
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
            
            Text("즐겨찾기")
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
                Text("선택")
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
            }
            .frame(width: 120, height: 34, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())

            Button {
                // TODO: - 즐겨찾기 내 사진 추가 연결
            } label: {
                Text("사진 추가")
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
