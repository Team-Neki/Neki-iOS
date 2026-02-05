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
        
        var currentItemID: Int
        let folderId: Int?
        
        var slidingPhotos: IdentifiedArrayOf<ArchiveImageItem> {
            if let folderId = folderId {
                let filteredItems = photos.filter { $0.folderId == folderId }
                return IdentifiedArray(uniqueElements: filteredItems)
            } else {
                return photos
            }
        }
        
        var currentItem: ArchiveImageItem? {
            photos[id: currentItemID]
        }
        
        var formattedDate: String {
            guard let date = currentItem?.date else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: date)
        }
        
        var isLoading: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onTapBackButton
        case onTapDownload
        case downloadImageResponse(successCount: Int)
        
        case onTapFavorite
        case toggleFavoriteResponse(photoID: Int, result: Result<Void, Error>)
        
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
                guard let item = state.currentItem else { return .none }
                let newStatus = !item.isFavorite
                
                state.$photos.withLock { $0[id: item.id]?.isFavorite = newStatus }
                
                return .run { [id = item.id, isFavorite = newStatus] send in
                    do {
                        try await archiveClient.toggleFavorite(photoID: id, request: isFavorite)
                        await send(.toggleFavoriteResponse(photoID: id, result: .success(())))
                    } catch {
                        await send(.toggleFavoriteResponse(photoID: id, result: .failure(error)))
                    }
                }
                
            case .toggleFavoriteResponse(_, .success):
                return .none
                
            case let .toggleFavoriteResponse(photoID, .failure):
                state.$photos.withLock { $0[id: photoID]?.isFavorite.toggle() }
                
                return .send(.delegate(.showToast(NekiToastItem("즐겨찾기 변경에 실패했어요", style: .error))))
                
            case .onTapDownload:
                guard let url = state.currentItem?.imageURL else {
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
                guard let id = state.currentItem?.id else { return .none }
                return .run { send in
                    do {
                        try await archiveClient.deletePhotoList(photoIds: [id])
                        await send(.deletePhotoResponse(.success(())))
                    } catch {
                        await send(.deletePhotoResponse(.failure(error)))
                    }
                }
                
            case .deletePhotoResponse(.success):
                guard let deletedID = state.currentItem?.id else { return .none }
                
                let deletedIndex = state.slidingPhotos.index(id: deletedID)
                
                state.$photos.withLock { _ = $0.remove(id: deletedID) }
                
                if state.slidingPhotos.isEmpty {
                    return .run { send in
                        await send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                        await dismiss()
                    }
                }
                
                if let index = deletedIndex, index < state.slidingPhotos.count {
                    state.currentItemID = state.slidingPhotos[index].id
                } else if let last = state.slidingPhotos.last {
                    state.currentItemID = last.id
                }
                
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
            case .deletePhotoResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제하지 못했어요", style: .error))))
                
            default:
                return .none
            }
        }
    }
    
}
