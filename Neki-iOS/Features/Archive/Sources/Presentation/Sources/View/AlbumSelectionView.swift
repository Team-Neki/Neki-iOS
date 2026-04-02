//
//  AlbumSelectionView.swift
//  Neki-iOS
//
//  Created by OneTen on 4/2/26.
//

import SwiftUI
import ComposableArchitecture

struct AlbumSelectionView: View {
    @Bindable var store: StoreOf<AlbumSelectionFeature>
    
    @State var addAlbumSheetPresented: Bool = false
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Header
                header
                
                if store.isFetching && store.albums.isEmpty {
                    LoadingView(message: "앨범에 추가하고 있어요.")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 새 앨범 추가 버튼
                            Button {
                                addAlbumSheetPresented = true
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.primary400, style: StrokeStyle(lineWidth: 1, lineCap: .round, dash:[5,5], dashPhase: 0))
                                            .frame(width: 72, height: 72)
                                            .background(Color.white)
                                        
                                        Image(.iconPlusRed)
                                    }
                                    
                                    Text("새 앨범 추가")
                                        .nekiFont(.body16SemiBold)
                                        .foregroundStyle(.gray900)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // 앨범 목록 리스트
                            ForEach(store.albums) { album in
                                AlbumRowTile(
                                    album: album,
                                    isSelectMode: true,
                                    isDeleteMode: false,
                                    isSelected: store.selectedAlbumId == album.id
                                )
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // 즐겨찾기 앨범은 선택하지 못하도록 예외 처리
                                    if !album.isFavorite {
                                        store.send(.tapAlbum(album.id))
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color.white.ignoresSafeArea())
        }
        .task {
            await store.send(.onAppear).finish()
        }
        .sheet(isPresented: $addAlbumSheetPresented) {
            ArchiveAlbumInputSheet(
                style: .add,
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

extension AlbumSelectionView {
    private var header: some View {
        ZStack(alignment: .center) {
            HStack {
                Button {
                    store.send(.tapBack)
                } label: {
                    Image(.iconChevronLeft)
                }
                
                Spacer()
                
                Button {
                    store.send(.tapConfirm)
                } label: {
                    Text("\(store.uploadCount)장 업로드")
                        .nekiFont(.body16SemiBold)
                        .foregroundStyle(store.selectedAlbumId == nil ? .gray200 : .primary500)
                }
                .disabled(store.selectedAlbumId == nil)
            }
            .frame(height: 54)
            .padding(.horizontal, 20)
            
            Text("앨범에 추가")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
        }
        .frame(height: 54)
    }
}
