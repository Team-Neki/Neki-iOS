//
//  ArchiveAlbumDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ArchiveAlbumDetailFeature {
    
    @ObservableState
    struct State {
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        
        let album: AlbumItem
        
        var selectedIDs: Set<Int> = []
        
        var isSelectionMode: Bool = false
        
        var filteredAlbumPhotos: IdentifiedArrayOf<ArchiveImageItem> {
            return photos
        }
        
        var isFetchingPhotos: Bool = false
        
        var isLoading: Bool = false
        
        var hasSelectedItems: Bool { !selectedIDs.isEmpty }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onAppear
        
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        
        // 기능 액션
        case onTapDownloadButton
        case downloadImagesResponse(successCount: Int)
        
        case onTapDeleteButton(option: ArchivePhotoDeleteOption)
        case deletePhotosResponse(Result<Void, Error>)
        
        case fetchPhotos
        case photoListResponse(Result<[PhotoEntity], Error>)
        case loadMorePhotos
        
        // 네비게이션
        case imageTapped(ArchiveImageItem)
        
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
                
            case .onAppear:
                return .send(.fetchPhotos)
                
            case .fetchPhotos:
                state.isFetchingPhotos = true
                
                return .run { [albumId = state.album.id] send in
                    await send(.photoListResponse(
                        Result {
                            try await archiveClient.fetchPhotoList(
                                folderId: albumId,
                                size: 20,
                                sortOrder: nil
                            )
                        }
                    ))
                }
                
            case let .photoListResponse(.success(entities)):
                state.isFetchingPhotos = false
                
                let currentAlbumId = state.album.id
                
                let newItems = entities.map { entity in
                    ArchiveImageItem(
                        id: entity.photoID,
                        imageURLString: entity.imageURL,
                        isFavorite: entity.isfavorite,
                        date: entity.createdAt.toISO8601Date(),
                        folderId: currentAlbumId
                    )
                }
                
                state.photos = IdentifiedArray(uniqueElements: newItems)
                return .none
                
            case .photoListResponse(.failure):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                return .send(.fetchPhotos)
                
            case .onTapSelectButton:
                state.isSelectionMode = true
                return .none
                
            case .onTapCancelSelectButton:
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .none
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if state.selectedIDs.contains(item.id) {
                        state.selectedIDs.remove(item.id)
                    } else {
                        state.selectedIDs.insert(item.id)
                    }
                }
                return .none
                
            case .onTapDownloadButton:
                guard !state.selectedIDs.isEmpty else { return .none }
                state.isLoading = true
                
                let urls = state.selectedIDs.compactMap { state.photos[id: $0]?.imageURL }
                
                return .run { send in
                    let count = try await imageDownloadClient.downloadImages(urls: urls)
                    await send(.downloadImagesResponse(successCount: count))
                }
                
            case let .downloadImagesResponse(count):
                state.isLoading = false
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                
                if count > 0 {
                    return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success))))
                } else {
                    return .send(.delegate(.showToast(NekiToastItem("사진 저장에 실패했어요", style: .error))))
                }
                
            case let .onTapDeleteButton(option):
                guard !state.selectedIDs.isEmpty else { return .none }
                
                let selectedIDs = Array(state.selectedIDs)
                let albumID = state.album.id
                
                return .run { send in
                    await send(.deletePhotosResponse(
                        Result {
                            if option == .fromAlbumOnly {
                                try await archiveClient.excludePhotosInAlbum(albumID, selectedIDs)
                            } else {
                                try await archiveClient.deletePhotoList(selectedIDs)
                            }
                        }
                    ))
                }
                
            case .deletePhotosResponse(.success):
                let idsToDelete = state.selectedIDs
                state.photos.removeAll { idsToDelete.contains($0.id) }
                
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
            case .deletePhotosResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제하지 못했어요", style: .error))))
                
            default:
                return .none
            }
        }
    }
}
