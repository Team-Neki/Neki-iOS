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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabView(selection: $store.currentItemID) {
                ForEach(store.photos) { item in
                    KFImage(item.imageURL)
                        .resizable()
                        .placeholder {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .retry(maxCount: 3, interval: .seconds(5))
                        .cancelOnDisappear(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            if let currentItem = store.currentItem {
                ArchiveImageFooter(
                    isEnabled: true,
                    isFavorite: currentItem.isFavorite,
                    onDownload: { store.send(.onTapDownload) },
                    onDelete: { showDeleteAlert = true },
                    onFavorite: { store.send(.onTapFavorite) }
                )
            }
        }
        .nekiToolbar(
            left: { NekiToolBar.back { store.send(.onTapBackButton) } },
            center: { NekiToolBar.textCenter(store.formattedDate) }
        )
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
