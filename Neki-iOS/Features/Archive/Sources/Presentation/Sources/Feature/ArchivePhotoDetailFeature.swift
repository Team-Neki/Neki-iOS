//
//  ArchivePhotoDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct ArchivePhotoDetailFeature {
    @ObservableState
    struct State {
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        let itemID: Int
        
        var item: ArchiveImageItem {
            get {
                photos[id: itemID] ?? ArchiveImageItem(
                    id: itemID,
                    imageURL: nil,
                    isFavorite: false,
                    date: Date(),
                    folderId: nil
                )
            }
            set {
                $photos.withLock { $0[id: itemID] = newValue }
            }
        }
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: item.date)
        }
        
        var isLoading: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onTapBackButton
        case onTapDownload
        case downloadImageResponse(successCount: Int)
        
        case onTapFavorite
        case toggleFavoriteResponse(Result<Void, Error>)
        
        case onTapDelete
        case deletePhotoResponse(Result<Void, Error>)
        
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.imageDownloadClient) var imageDownloadClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case .onTapFavorite:
                let newStatus = !state.item.isFavorite
                state.item.isFavorite = newStatus
                
                return .run { [id = state.itemID, isFavorite = newStatus] send in
                    await send(.toggleFavoriteResponse(Result {
                        try await archiveClient.toggleFavorite(photoID: id, request: isFavorite)
                    }))
                }
                
            case .toggleFavoriteResponse(.success):
                return .none
                
            case .toggleFavoriteResponse(.failure):
                state.item.isFavorite.toggle()
                return .send(.delegate(.showToast(NekiToastItem("즐겨찾기 변경에 실패했어요", style: .error))))
                
            case .onTapDownload:
                guard let url = state.item.imageURL else {
                    return .none
                }
                
                state.isLoading = true
                
                return .run { send in
                    let count = try await imageDownloadClient.downloadImages(urls: [url])
                    await send(.downloadImageResponse(successCount: count))
                }
                
            case let .downloadImageResponse(count):
                state.isLoading = false
                
                if count > 0 {
                    return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success))))
                } else {
                    return .send(.delegate(.showToast(NekiToastItem("사진 저장에 실패했어요", style: .error))))
                }
                
            case .onTapDelete:
                return .run { [id = state.itemID] send in
                    await send(.deletePhotoResponse(Result {
                        try await archiveClient.deletePhotoList(photoIds: [id])
                    }))
                }
                
            case .deletePhotoResponse(.success):
                state.$photos.withLock { _ = $0.remove(id: state.itemID) }
                
                return .run { send in
                    await send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                    await dismiss()
                }
                
            case .deletePhotoResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제하지 못했어요", style: .error))))
                
            default:
                return .none
            }
        }
    }
    
}
