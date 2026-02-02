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
        @Shared var sharedAlbums: IdentifiedArrayOf<AlbumItem>
        
        let album: AlbumItem
        
        var selectedIDs: Set<Int> = []
        
        var isSelectionMode: Bool = false
        
        var filteredAlbumPhotos: IdentifiedArrayOf<ArchiveImageItem> {
            let items = photos.filter { $0.folderId == album.id }
            return IdentifiedArray(uniqueElements: items)
        }
        
        var currentPage: Int = 0
        var hasNext: Bool = true
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
        case deletePhotosResponse(ArchivePhotoDeleteOption, Result<Void, Error>)
        
        case fetchAlbums
        case albumListResponse(Result<[AlbumItem], Error>)
        
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
    @Dependency(\.imageDownloadClient) var imageDownloadClient
    
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
                        id: entity.photoID,
                        imageURLString: entity.imageURL,
                        isFavorite: entity.isfavorite,
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
                guard !state.selectedIDs.isEmpty else { return .none }
                state.isLoading = true

                let selectedURLs: [URL] = state.selectedIDs.compactMap { id in
                        return state.photos[id: id]?.imageURL
                    }
                
                guard !selectedURLs.isEmpty else {
                    state.isLoading = false
                    return .none
                }
                
                return .run { send in
                    let count = try await imageDownloadClient.downloadImages(urls: selectedURLs)
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
                
                return .run { [ids = state.selectedIDs, albumId = state.album.id] send in
                    await send(.deletePhotosResponse(
                        option,
                        Result {
                            if option == .fromAlbumOnly {
                                try await archiveClient.excludePhotosInAlbum(albumID: albumId, photoIDs: Array(ids))
                            } else {
                                try await archiveClient.deletePhotoList(photoIds: Array(ids))
                            }
                        }
                    ))
                }
                
            case let .deletePhotosResponse(option, .success):
                
                state.$photos.withLock { photos in
                    if option == .fromAlbumOnly {
                        for id in state.selectedIDs {
                            photos[id: id]?.folderId = nil
                        }
                    } else {
                        photos.removeAll { state.selectedIDs.contains($0.id) }
                    }
                }
                
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                
                let toastItem = NekiToastItem("사진을 삭제했어요", style: .success)
                
                return .merge(
                    .send(.delegate(.showToast(toastItem))),
                    .send(.fetchPhotos(isRefresh: true)),
                    .send(.fetchAlbums)
                )
                
            case .deletePhotosResponse(_, .failure):
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제하지 못했어요", style: .error))))
                
            case .fetchAlbums:
                return .run { send in
                    await send(.albumListResponse(Result {
                        let entities = try await archiveClient.getAlbumList()
                        return entities.map {
                            AlbumItem(
                                id: $0.id,
                                title: $0.name,
                                count: $0.photoCount,
                                coverImageURL: URL(string: $0.coverImageURLString),
                                isFavorite: false
                            )
                        }
                    }))
                }
                
            case let .albumListResponse(.success(newAlbums)):
                state.$sharedAlbums.withLock { existing in
                    var favoriteAlbum: AlbumItem?
                    if let first = existing.first, first.isFavorite {
                        favoriteAlbum = first
                    }
                    
                    var mergedAlbums: [AlbumItem] = []
                    
                    if let fav = favoriteAlbum {
                        mergedAlbums.append(fav)
                    }
                    
                    mergedAlbums.append(contentsOf: newAlbums)
                    
                    existing = IdentifiedArray(uniqueElements: mergedAlbums)
                }
                return .none
                
            case .albumListResponse(.failure):
                return .none
                
            default:
                return .none
            }
        }
    }
}
