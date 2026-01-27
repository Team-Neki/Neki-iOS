//
//  ArchiveFavoriteAlbumFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct ArchiveFavoriteAlbumFeature {
    @ObservableState
    struct State {
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        let album: AlbumItem
        
        var selectedIDs: Set<Int> = []
        var isSelectionMode: Bool = false
        
        var currentPage: Int = 0
        var hasNext: Bool = true
        var isFetchingPhotos: Bool = false
        
        var hasSelectedItems: Bool { !selectedIDs.isEmpty }
        
        var filteredItems: IdentifiedArrayOf<ArchiveImageItem> {
            let items = photos.filter { $0.isFavorite == true }
            return IdentifiedArray(uniqueElements: items)
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onAppear
        case fetchFavoritePhotos(isRefresh: Bool)
        case favoritePhotoListResponse(Result<(photos: [PhotoEntity], hasNext: Bool), Error>)
        case loadMorePhotos
        
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        
        // 기능 액션
        case onTapDownloadButton
        case onTapDeleteButton
        
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
                return .send(.fetchFavoritePhotos(isRefresh: true))
                
            case let .fetchFavoritePhotos(isRefresh):
                if isRefresh {
                    state.currentPage = 0
                    state.hasNext = true
                }
                
                guard state.hasNext, !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                
                return .run { [page = state.currentPage] send in
                    await send(.favoritePhotoListResponse(
                        Result {
                            try await archiveClient.fetchFavoritePhotoList(
                                page: page,
                                size: 20,
                                sortOrder: "DESC"
                            )
                        }
                    ))
                }
                
            case let .favoritePhotoListResponse(.success(result)):
                state.isFetchingPhotos = false
                state.hasNext = result.hasNext
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let newItems = result.photos.map { entity in
                    ArchiveImageItem(
                        id: entity.photoId,
                        imageURLString: entity.imageUrl,
                        isScrapped: true,
                        date: isoFormatter.date(from: entity.createdAt) ?? Date(),
                        folderId: entity.folderId
                    )
                }
                
                state.$photos.withLock { sharedPhotos in
                    for item in newItems {
                        sharedPhotos.updateOrAppend(item)
                    }
                }
                
                state.currentPage += 1
                return .none
                
            case let .favoritePhotoListResponse(.failure(error)):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                return .send(.fetchFavoritePhotos(isRefresh: false))
                
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
                state.$photos.withLock {
                    $0.removeAll { state.selectedIDs.contains($0.id) }
                }
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
            default:
                return .none
            }
        }
    }
}
