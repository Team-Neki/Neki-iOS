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
            KFImage(store.item.imageURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .retry(maxCount: 3, interval: .seconds(5))
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
            ArchiveImageFooter(
                isEnabled: true,
                isFavorite: store.item.isFavorite,
                onDownload: { store.send(.onTapDownload) },
                onDelete: { showDeleteAlert = true },
                onFavorite: { store.send(.onTapFavorite) }
            )
        }
        .nekiToolbar(
            left: { NekiToolBar.back { store.send(.onTapBackButton) } },
            center: { NekiToolBar.textCenter(store.formattedDate) }
        )
        .nekiAlert(
            isPresented: $showDeleteAlert,
            style: .cancelable,
            titleMessage: "사진을 삭제하시겠어요?",
            subTitleMessage: "이 작업은 실행취소할 수 없어요",
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
