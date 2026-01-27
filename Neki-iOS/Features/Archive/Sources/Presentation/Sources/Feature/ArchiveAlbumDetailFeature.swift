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
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        let album: AlbumItem
        
        var selectedIDs: Set<Int> = []
        var deleteOption: ArchivePhotoDeleteOption = .fromAlbumOnly
        
        var isSelectionMode: Bool = false
        
        var filteredAlbumPhotos: IdentifiedArrayOf<ArchiveImageItem> {
            let items = photos.filter { $0.folderId == album.id }
            return IdentifiedArray(uniqueElements: items)
        }
        
        var currentPage: Int = 0
        var hasNext: Bool = true
        var isFetchingPhotos: Bool = false
        
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
        
        case onTapDeleteButton
        case deletePhotos
        case deletePhotosResponse(Result<Void, Error>)
        
        case fetchPhotos(isRefresh: Bool)
        case photoListResponse(Result<(photos: [PhotoEntity], hasNext: Bool), Error>)
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
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case .onAppear:
                return .send(.fetchPhotos(isRefresh: true))
                
            case let .fetchPhotos(isRefresh):
                if isRefresh {
                    state.currentPage = 0
                    state.hasNext = true
                }
                
                guard state.hasNext, !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                
                return .run { [page = state.currentPage, albumId = state.album.id] send in
                    await send(.photoListResponse(
                        Result {
                            try await archiveClient.fetchPhotoList(
                                folderId: albumId,
                                page: page,
                                size: 20,
                                sortOrder: nil
                            )
                        }
                    ))
                }
                
            case let .photoListResponse(.success(result)):
                state.isFetchingPhotos = false
                state.hasNext = result.hasNext
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let currentAlbumId = state.album.id
                
                let newItems = result.photos.map { entity in
                    ArchiveImageItem(
                        id: entity.photoId,
                        imageURLString: entity.imageUrl,
                        isScrapped: entity.favorite,
                        date: isoFormatter.date(from: entity.createdAt) ?? Date(),
                        folderId: currentAlbumId
                    )
                }
                
                state.$photos.withLock { sharedPhotos in
                    for item in newItems {
                        sharedPhotos.updateOrAppend(item)
                    }
                }
                
                state.currentPage += 1
                return .none
                
            case .photoListResponse:
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                return .send(.fetchPhotos(isRefresh: false))
                
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
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success))))
                
            case .onTapDeleteButton:
                guard !state.selectedIDs.isEmpty else { return .none }
                return .send(.deletePhotos)
                
            case .deletePhotos:
                return .run { [ids = state.selectedIDs] send in
                    await send(.deletePhotosResponse(Result {
                        try await archiveClient.deletePhotoList(photoIds: Array(ids))
                    }))
                }
                
            case .deletePhotosResponse(.success):
                state.$photos.withLock { photos in
                    photos.removeAll { state.selectedIDs.contains($0.id) }
                }
                
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
