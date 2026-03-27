//
//  ArchiveAllPhotosFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/19/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ArchiveAllPhotosFeature {
    
    @ObservableState
    struct State {
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        var selectedIDs: Set<Int> = []
        
        var selectedSortedTime: String = "최신순" // "최신순" == DESC, "오래된순" == ASC
        var isSelectedFavorite: Bool = false
        var isSelectionMode: Bool = false
        
        var isFetchingPhotos: Bool = false
        
        // 선택된 사진이 있는지 여부
        var hasSelectedItems: Bool {
            return !selectedIDs.isEmpty
        }
        
        var filteredItems: IdentifiedArrayOf<ArchiveImageItem> {
            let filtered = isSelectedFavorite ? photos.filter { $0.isFavorite } : photos
            return IdentifiedArray(uniqueElements: filtered)
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // View Life Cycle Action
        case onAppear
        
        // User Action
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        
        case onTapFavorite(item: ArchiveImageItem)
        case toggleFavoriteResponse(photoID: Int, result: Result<Void, Error>)
        
        case onTapDownloadButton
        case downloadImagesResponse(successCount: Int)
        
        // Delete Action
        case onTapDeleteButton
        case deletePhotosLocally(ids: [Int])
        
        // Filter Action
        case onTapFilterNewest
        case onTapFilterOldest
        case onTapFavoriteButton
        
        // Fetch Photo Action
        case fetchPhotos
        case photoListResponse(Result<[PhotoEntity], Error>)
        case loadMorePhotos
        
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
                
                // MARK: - View Life Cycle Action
                
            case .onAppear:
                return .send(.fetchPhotos)
                
                // MARK: - User Action
                
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case .onTapSelectButton:
                state.isSelectionMode = true
                return .none
                
            case .onTapCancelSelectButton:
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .none
                
            case let .onTapFavorite(item):
                let newStatus = !item.isFavorite
                
                state.photos[id: item.id]?.isFavorite = newStatus
                
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
                state.photos[id: photoID]?.isFavorite.toggle()
                return .send(.delegate(.showToast(NekiToastItem("즐겨찾기 변경에 실패했어요", style: .error))))
                
            case .onTapDownloadButton:
                guard !state.selectedIDs.isEmpty else { return .none }
                
                let urls = state.selectedIDs.compactMap { state.photos[id: $0]?.imageURL }
                
                return .run { send in
                    let count = try await imageDownloadClient.downloadImages(urls: urls)
                    await send(.downloadImagesResponse(successCount: count))
                }
                
            case let .downloadImagesResponse(count):
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                
                if count > 0 {
                    return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success))))
                } else {
                    return .send(.delegate(.showToast(NekiToastItem("사진 저장에 실패했어요", style: .error))))
                }
                
                
                // MARK: - Delete Action
                
            case .onTapDeleteButton:
                return .run { [selectedIDs = state.selectedIDs] send in
                    try await archiveClient.deletePhotoList(photoIds: Array(selectedIDs))
                    await send(.deletePhotosLocally(ids: Array(selectedIDs)))
                }
                
            case let .deletePhotosLocally(ids):
                state.photos.removeAll { ids.contains($0.id) }
                
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
                
                // MARK: - Filter Action
                
            case .onTapFilterNewest:
                if state.selectedSortedTime == "최신순" { return .none }
                state.selectedSortedTime = "최신순"
                state.photos.removeAll()
                return .send(.fetchPhotos)
                
            case .onTapFilterOldest:
                if state.selectedSortedTime == "오래된순" { return .none }
                state.selectedSortedTime = "오래된순"
                state.photos.removeAll()
                return .send(.fetchPhotos)
                
            case .onTapFavoriteButton:
                state.isSelectedFavorite.toggle()
                return .none
                
                
                // MARK: - Fetch Photo Action
                
            case .fetchPhotos:
                guard !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                
                // "최신순" -> "DESC", "오래된순" -> "ASC" 변환
                let sortOrder = state.selectedSortedTime == "최신순" ? "DESC" : "ASC"
                
                return .run { send in
                    await send(.photoListResponse(
                        Result {
                            try await archiveClient.fetchPhotoList(folderId: nil, size: 20, sortOrder: sortOrder)
                        }
                    ))
                }
                
            case let .photoListResponse(.success(entities)):
                state.isFetchingPhotos = false
    
                let newItems = entities.map { entity in
                    ArchiveImageItem(
                        id: entity.photoID,
                        imageURLString: entity.imageURL,
                        isFavorite: entity.isfavorite,
                        date: entity.createdAt.toISO8601Date(),
                        folderId: entity.folderID,
                        memo: entity.memo ?? ""
                    )
                }
                
                state.photos = IdentifiedArray(uniqueElements: newItems)
                return .none
                
            case .photoListResponse(.failure):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                return .send(.fetchPhotos)
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if state.selectedIDs.contains(item.id) {
                        state.selectedIDs.remove(item.id)
                    } else {
                        state.selectedIDs.insert(item.id)
                    }
                } else {
                    // 상세 화면 이동 로직 (Coordinator에서 처리)
                }
                return .none
                
            default:
                return .none
            }
        }
    }
}
