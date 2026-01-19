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
    
    var body: some View {
        ZStack(alignment: .top) {
            masonryView
            
            filterBar
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .padding(.bottom, 12)
                .background(.white)
                .offset(y: isFilterBarVisible ? 0 : -100)
        }
        // TODO: - 툴바 액션 연결
        .nekiToolbar(left: .back(action: { store.send(.onTapBackButton) }), center: .text("모든 사진"), right: .text("선택", action: { store.send(.onTapSelectButton) }))
        .navigationBarHidden(true)
        .background(.white)
    }
}

private extension ArchiveAllPhotosView {
    @ViewBuilder
    var masonryView: some View {
        ScrollView {
            MasonryGridView(
                items: Array(store.filteredItems),
                columns: 2
            ) { item in
                ArchiveImageView(item: item)
                    .onTapGesture {
                        store.send(.imageTapped(item))
                    }
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
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
                        .padding(.top, 45)
                        .padding(.leading, 10)
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
        .overlay(content: {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.gray.opacity(0.5), lineWidth: 1)
                .shadow(color: .gray.opacity(0.5), radius: 2)
        })
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
                .padding(.vertical, 5)
        }
    }
    
}

#Preview {
    ArchiveAllPhotosView(
        store: Store(
            initialState: ArchiveAllPhotosFeature.State(
                photos: IdentifiedArray(uniqueElements: ArchiveImageItem.dummyData())
            )
        ) {
            ArchiveAllPhotosFeature()
        }
    )
}
