//
//  SelectUploadAlbumView.swift
//  Neki-iOS
//

import SwiftUI
import ComposableArchitecture

struct SelectUploadAlbumView: View {
    @Bindable var store: StoreOf<SelectUploadAlbumFeature>
    
    var body: some View {
        ZStack {
            switch store.viewMode {
            case .prompt:
                promptPopupView
                    .transition(.opacity)
                
            case .albumList:
                if let childStore = store.scope(state: \.albumSelection, action: \.albumSelection) {
                    NavigationStack {
                        AlbumSelectionView(store: childStore)
                    }
                }
            }
            
            if store.isLoading {
                LoadingView(message: "사진을 업로드하고 있어요.")
            }
        }
        .animation(.easeInOut, value: store.viewMode)
    }
}

// MARK: - Subviews

private extension SelectUploadAlbumView {
    
    @ViewBuilder
    var promptPopupView: some View {
        Color.gray900.opacity(0.5)
            .onTapGesture {
                store.send(.tapDimmedBackground)
            }
        
        VStack(alignment: .center, spacing: 4) {
            Button {
                store.send(.tapUploadWithoutAlbum)
            } label: {
                Text("앨범 없이 업로드하기")
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray800)
            }
            .padding(.vertical, 14)
            
            Divider()
            
            Button {
                store.send(.tapSelectAlbumAndUpload)
            } label: {
                HStack {
                    Text("앨범 선택 후 업로드하기")
                        .nekiFont(.body16SemiBold)
                        .foregroundStyle(.gray800)
                }
                .padding(.vertical, 14)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 33)
    }
}
