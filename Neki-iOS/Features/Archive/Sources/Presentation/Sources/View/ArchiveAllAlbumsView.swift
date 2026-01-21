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
    @State var deleteAlbumSheetPresented: Bool = false
    @State var showDropDownButton: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(store.albums) { album in
                            AlbumRowTile(
                                album: album,
                                isDeleteMode: store.isDeleteMode,
                                isSelected: store.selectedAlbumIDs.contains(album.id)
                            )
                            .onTapGesture {
                                if store.isDeleteMode {
                                    store.send(.onTapToggleSelection(album))
                                } else {
                                    store.send(.onTapAlbum(album))
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                
            }
            
            if showDropDownButton && !store.isDeleteMode {
                // TODO: - 삭제하기 드롭다운버튼이 나타나 있을 경우 다른 이벤트 가능한지 여부 물어보기
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { showDropDownButton = false }
                    }
                
                dropDownButton
                    .padding(.top, 47)
                    .padding(.trailing, 20)
            }
            
        }
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
        .sheet(isPresented: $deleteAlbumSheetPresented) {
            ArchiveDeleteSheet(
                selectedOption: $store.deleteOption,
                title: "앨범을 삭제하시겠어요?",
                firstOption: (.withPhotos, "사진까지 함께 삭제"),
                secondOption: (.albumOnly, "사진은 유지하고 앨범만 삭제"),
                onCancel: {
                    deleteAlbumSheetPresented = false
                },
                onConfirm: {
                    store.send(.onTapExecuteDelete)
                    deleteAlbumSheetPresented = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationCornerRadius(20)
        }
    }
}

private extension ArchiveAllAlbumsView {
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
                    if store.isDeleteMode {
                        Button {
                            deleteAlbumSheetPresented = true
                        } label: {
                            Text("삭제")
                                .nekiFont(.body16SemiBold)
                                .foregroundStyle(store.selectedAlbumIDs.isEmpty ? .gray200 : .primary500)
                        }
                        .disabled(store.selectedAlbumIDs.isEmpty)
                    } else {
                        Button {
                            addAlbumSheetPresented = true
                        } label: {
                            Text("생성")
                                .nekiFont(.body16SemiBold)
                                .foregroundStyle(.primary500)
                        }
                        
                        Button {
                            withAnimation { showDropDownButton.toggle() }
                        } label: {
                            Image(.iconEllipsis)
                        }
                    }
                }
            }
            
            Text("모든 앨범")
                .nekiFont(.title18SemiBold)
                .foregroundStyle(.gray900)
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
    }
    
    var dropDownButton: some View {
        Button {
            store.send(.onTapEnterDeleteMode)
            withAnimation { showDropDownButton = false }
        } label: {
            Text("삭제하기")
                .nekiFont(.body16Medium)
                .foregroundStyle(.gray900)
        }
        .frame(width: 130, height: 34, alignment: .leading)
        .padding(.leading, 12)
        .padding(.vertical, 8)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(content: {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.5), lineWidth: 1)
                .shadow(color: .gray.opacity(0.5), radius: 2)
        })
        .background(.white)
    }
    
}
