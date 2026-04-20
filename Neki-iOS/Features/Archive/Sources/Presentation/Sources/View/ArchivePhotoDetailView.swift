//
//  ArchivePhotoDetailView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct ArchivePhotoDetailView: View {
    @Bindable var store: StoreOf<ArchivePhotoDetailFeature>
    
    @State var showDeleteAlert: Bool = false
    @FocusState private var isMemoEditingFocused: Bool
    
    var body: some View {
        ZStack {
            // 사진 영역
            photoTabView
                .ignoresSafeArea()
            
            // 툴바
            VStack(spacing: 0) {
                topToolbar
                    .background(.white)
                Spacer()
            }
            
            // 딤처리
            dimmedBackground
                .ignoresSafeArea()
            
            // 하단 메모 및 푸터 UI
            bottomContainer
            
            if store.isLoading {
                LoadingView(message: "요청을 처리하고 있어요.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            if store.showDropDownMenu {
                // 메뉴 외부 빈 공간 터치 시 드롭다운 닫기
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.send(.closeDropDownMenu)
                    }
                
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        dropDownMenu
                            .padding(.top, 45)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .zIndex(10)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: store.currentItemID) { _, _ in
            store.send(.closeDropDownMenu)
            store.send(.binding(.set(\.isMemoVisible, false)))
            store.send(.toggleMemoExpanded(false))
            store.send(.binding(.set(\.isMemoEditing, false)))
            isMemoEditingFocused = false
        }
        .onChange(of: store.isMemoEditing) { _, isEditing in
            isMemoEditingFocused = isEditing
        }
        .fullScreenCover(
            item: $store.scope(state: \.imageTransform, action: \.imageTransform)
        ) { transformStore in
            NavigationStack {
                ImageTransformView(store: transformStore)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: {
                                transformStore.send(.closeButtonTapped)
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
            }
        }
        .fullScreenCover(item: $store.scope(state: \.albumSelection, action: \.albumSelection)) { selectionStore in
            AlbumSelectionView(store: selectionStore)
        }
        .nekiAlert(
            isPresented: $showDeleteAlert,
            style: .cancelable,
            title: "사진을 삭제하시겠어요?",
            subtitle: "이 작업은 실행취소할 수 없어요",
            confirmText: "삭제하기",
            cancelText: "취소",
            onConfirm: {
                store.send(.onTapDelete)
                showDeleteAlert = false
            },
            onCancel: {
                showDeleteAlert = false
            }
        )
    }
}


// MARK: - Subviews

extension ArchivePhotoDetailView {
    // 툴바
    private var topToolbar: some View {
        NekiToolbarLayout(
            backgroundColor: Color(.systemBackground),
            left: { NekiToolBar.back { store.send(.onTapBackButton) } },
            center: { NekiToolBar.textCenter(store.formattedDate) },
            right: {
                Button {
                    store.send(.toggleDropDownMenu)
                } label: {
                    Image(.iconEllipsis)
                        .frame(width: 24, height: 24)
                        .padding(8)
                }
            }
        )
    }
    
    private var dropDownMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                store.send(.onTapAddToAlbum)
            } label: {
                Text("앨범에 추가")
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
            }
            .frame(width: 158, height: 34, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())
            
            
            // MARK: - 내부 테스트 전용 기능
            #if DEBUG
            Button {
                store.send(.onTapTransform)
            } label: {
                Text("이미지 변환")
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
            }
            .frame(width: 158, height: 34, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())
            
            Button {
                store.send(.onTapShareToInstagramStory)
            } label: {
                Text("인스타 스토리 공유")
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
            }
            .frame(width: 158, height: 34, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())
            #endif
            
        }
        .padding(.vertical, 8)
        .frame(width: 158, alignment: .topLeading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 2.5, x: 0, y: 0)
    }
    
    private var photoTabView: some View {
        TabView(selection: $store.currentItemID) {
            ForEach(store.photos) { item in
                ZoomableImageView(
                    imageURL: item.imageURL,
                    isCurrent: store.currentItemID == item.id
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tag(item.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 딤처리 영역
    @ViewBuilder
    private var dimmedBackground: some View {
        if store.isMemoExpanded || store.isMemoEditing {
            Color.black.opacity(0.5)
                .onTapGesture {
                    if !store.isMemoEditing {
                        store.send(.toggleMemoExpanded(false))
                    }
                }
        }
    }
    
    // 하단 UI 컨테이너
    private var bottomContainer: some View {
        VStack(spacing: 0) {
            Spacer()
            
            memoSection
            footerSection
        }
    }
    
    // 메모 영역 전체
    @ViewBuilder
    private var memoSection: some View {
        if store.isMemoVisible {
            VStack(alignment: .leading, spacing: 0) {
                Color.gray75.frame(height: 1)
                
                if store.isMemoEditing {
                    editingMemoView
                } else {
                    viewingMemoView
                }
            }
        }
    }
    
    // 메모 편집 모드 UI
    private var editingMemoView: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("자유롭게 메모를 입력해주세요 (최대 100자)", text: $store.editingMemoText, axis: .vertical)
                .maxLength(100, text: $store.editingMemoText)
                .nekiFont(.body16Regular)
                .foregroundStyle(.gray700)
                .focused($isMemoEditingFocused)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            HStack(alignment: .center, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text("\(store.editingMemoText.count)/100")
                        .nekiFont(.caption12Regular)
                        .foregroundStyle(.gray300)
                    
                    Button {
                        store.send(.clearAllMemoEditing)
                    } label: {
                        Text("전체 지우기")
                            .nekiFont(.caption12Medium)
                            .foregroundStyle(store.editingMemoText.isEmpty ? .gray200 : .gray600)
                    }
                }
                
                Spacer()
                
                HStack(alignment: .center, spacing: 16) {
                    Button {
                        store.send(.cancelMemoEditing)
                        isMemoEditingFocused = false
                    } label: {
                        Text("취소")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.gray800)
                    }
                    
                    Button {
                        store.send(.doneMemoEditing)
                        isMemoEditingFocused = false
                    } label: {
                        Text("완료")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.primary500)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.gray25)
    }
    
    // 메모 조회 모드 UI
    private var viewingMemoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let currentMemo = store.currentItem?.memo ?? ""
            
            if store.isMemoExpanded {
                Text(currentMemo)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray700)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        store.send(.startMemoEditing)
                    }
                    .padding(.horizontal, 20)
                
                HStack {
                    Spacer()
                    Button {
                        store.send(.toggleMemoExpanded(false))
                    } label: {
                        Text("메모 접기")
                            .nekiFont(.body16Medium)
                            .foregroundStyle(.gray200)
                    }
                }
                .padding(.horizontal, 20)
                
            } else {
                HStack(alignment: .top, spacing: 4) {
                    Text(currentMemo.isEmpty ? "자유롭게 메모를 입력해주세요 (최대 100자)" : currentMemo)
                        .lineLimit(1)
                        .nekiFont(.body16Medium)
                        .foregroundColor(currentMemo.isEmpty ? .gray300 : .gray700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.startMemoEditing)
                        }
                    
                    if currentMemo.count >= 20 {
                        Button {
                            store.send(.toggleMemoExpanded(true))
                        } label: {
                            Text("더 보기")
                                .nekiFont(.body16Medium)
                                .foregroundStyle(.gray300)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(.white)
    }
    
    // 푸터 영역
    @ViewBuilder
    private var footerSection: some View {
        if let currentItem = store.currentItem {
            if !store.isMemoEditing {
                ArchiveImageFooter(
                    isEnabled: true,
                    isFavorite: currentItem.isFavorite,
                    hasMemo: !currentItem.memo.isEmpty,
                    onDownload: { store.send(.onTapDownload) },
                    onDelete: { showDeleteAlert = true },
                    onFavorite: { store.send(.onTapFavorite) },
                    onTapMemo: { store.send(.toggleMemoVisibility) }
                )
            }
        }
    }
}

fileprivate extension TextField {
    func maxLength(_ length: Int, text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > length {
                text.wrappedValue = String(newValue.prefix(length))
            }
        }
    }
}
