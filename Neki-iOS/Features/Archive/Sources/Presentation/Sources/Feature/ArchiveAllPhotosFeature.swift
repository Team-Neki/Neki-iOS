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
    private enum CancelID: Hashable {
        case photoRequest
    }

    @ObservableState
    struct State: Equatable {
        @Presents var albumSelection: AlbumSelectionFeature.State?
        
        var photos: IdentifiedArrayOf<PhotoEntity> = []
        var visiblePhotos: [PhotoEntity] = []
        var lastVisiblePhotoID: Int?
        var selectedIDs: Set<Int> = []
        var selectedSortOrder: ArchivePhotoSortOrder = .descending
        var isSelectedFavorite: Bool = false
        var isSelectionMode: Bool = false
        var isFetchingPhotos: Bool = false
        var hasNextPhotos: Bool = true
        var hasSelectedItems: Bool { return !selectedIDs.isEmpty }
        var isLoading: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        case onTapFavorite(item: PhotoEntity)
        case toggleFavoriteResponse(photoID: Int, result: Result<Void, Error>)
        case onTapDownloadButton
        case downloadImagesResponse(successCount: Int)
        case onTapDeleteButton
        case deletePhotosLocally(ids: [Int])
        case onTapSortOrder(ArchivePhotoSortOrder)
        case onTapFavoriteButton
        case fetchPhotos
        case photoListResponse(Result<ArchivePhotoSnapshot, Error>)
        case loadMorePhotos
        case imageTapped(PhotoEntity)
        
        case onTapDuplicateButton
        case onTapMoveButton
        case albumSelection(PresentationAction<AlbumSelectionFeature.Action>)
        
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.imageDownloadClient) var imageDownloadClient
    @Dependency(\.analyticsClient) var analyticsClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear: return .send(.fetchPhotos)
            case .onTapBackButton: return .run { _ in await dismiss() }
                
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
                state.updateVisiblePhoto(id: item.id)
                return .run { [id = item.id, isFavorite = newStatus] send in
                    do {
                        try await archiveClient.toggleFavorite(photoID: id, request: isFavorite)
                        await send(.toggleFavoriteResponse(photoID: id, result: .success(())))
                    } catch {
                        await send(.toggleFavoriteResponse(photoID: id, result: .failure(error)))
                    }
                }
                
            case .toggleFavoriteResponse(_, .success): return .none
            case let .toggleFavoriteResponse(photoID, .failure):
                state.photos[id: photoID]?.isFavorite.toggle()
                state.updateVisiblePhoto(id: photoID)
                return .send(.delegate(.showToast(NekiToastItem("즐겨찾기 변경에 실패했어요", style: .error))))
                
            case .onTapDownloadButton:
                guard !state.selectedIDs.isEmpty else { return .none }
                state.isLoading = true
                return .run { [photos = state.photos, selectedIDs = state.selectedIDs] send in
                    let urls = selectedIDs.compactMap { photos[id: $0]?.imageURL }
                    let count = try await imageDownloadClient.downloadImages(urls: urls)
                    await send(.downloadImagesResponse(successCount: count))
                }
                
            case let .downloadImagesResponse(count):
                state.isLoading = false
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                if count > 0 { return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success)))) }
                else { return .send(.delegate(.showToast(NekiToastItem("사진 저장에 실패했어요", style: .error)))) }
                
            case .onTapDeleteButton:
                return .run { [selectedIDs = state.selectedIDs] send in
                    try await archiveClient.deletePhotoList(photoIds: Array(selectedIDs))
                    await send(.deletePhotosLocally(ids: Array(selectedIDs)))
                }
                
            case let .deletePhotosLocally(ids):
                let deletedIDs = Set(ids)
                state.photos.removeAll { deletedIDs.contains($0.id) }
                state.updateVisiblePhotos()
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
            case let .onTapSortOrder(sortOrder):
                guard state.selectedSortOrder != sortOrder else { return .none }
                state.selectedSortOrder = sortOrder
                state.photos.removeAll()
                state.visiblePhotos.removeAll()
                state.lastVisiblePhotoID = nil
                return fetchPhotos(state: &state)
                
            case .onTapFavoriteButton:
                state.isSelectedFavorite.toggle()
                state.updateVisiblePhotos()
                return .none
                
            case .fetchPhotos:
                guard !state.isFetchingPhotos else { return .none }
                return fetchPhotos(state: &state)
                
            case let .photoListResponse(.success(snapshot)):
                state.isFetchingPhotos = false
                state.hasNextPhotos = snapshot.hasNext
                state.photos = IdentifiedArray(uniqueElements: snapshot.photos)
                state.updateVisiblePhotos()
                return .none
                
            case let .photoListResponse(.failure(error)):
                state.isFetchingPhotos = false
                guard error is CancellationError == false else { return .none }
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                guard state.isFetchingPhotos == false, state.hasNextPhotos else { return .none }
                state.isFetchingPhotos = true
                return .run { [sortOrder = state.selectedSortOrder] send in
                    await send(.photoListResponse(Result {
                        try await archiveClient.fetchNextPhotos(.all, 20, sortOrder)
                    }))
                }
                .cancellable(id: CancelID.photoRequest, cancelInFlight: true)
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if state.selectedIDs.contains(item.id) { state.selectedIDs.remove(item.id) }
                    else { state.selectedIDs.insert(item.id) }
                }
                return .none
                
            case .onTapDuplicateButton:
                state.albumSelection = AlbumSelectionFeature.State(photoIDs: Array(state.selectedIDs), selectionPurpose: .duplicate, currentAlbumId: nil)
                return .none
                
            case .onTapMoveButton:
                state.albumSelection = AlbumSelectionFeature.State(photoIDs: Array(state.selectedIDs), selectionPurpose: .move, currentAlbumId: nil)
                return .none
                
            case let .albumSelection(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .didCompleteTask(message, albumCount):
                    let photoCount = state.selectedIDs.count
                    state.albumSelection = nil
                    state.isSelectionMode = false
                    state.selectedIDs.removeAll()
                    
                    return .merge(
                        .run { _ in await analyticsClient.logEvent(ArchiveAnalyticsEvent.albumAddFromMulti(photoCount: photoCount, albumCount: albumCount)) },
                        .send(.delegate(.showToast(NekiToastItem(message, style: .success)))),
                        .send(.fetchPhotos)
                    )
                    
                case .didTapCancel:
                    state.albumSelection = nil
                    return .none
                    
                case let .showToast(toastItem):
                    return .send(.delegate(.showToast(toastItem)))
                    
                case .didSelectForUpload(albumId: _):
                    return .none
                }
                
            default: return .none
            }
        }
        .ifLet(\.$albumSelection, action: \.albumSelection) { AlbumSelectionFeature() }
    }

    private func fetchPhotos(state: inout State) -> Effect<Action> {
        state.isFetchingPhotos = true
        return .run { [sortOrder = state.selectedSortOrder] send in
            await send(.photoListResponse(Result {
                try await archiveClient.refreshPhotos(.all, 20, sortOrder)
            }))
        }
        .cancellable(id: CancelID.photoRequest, cancelInFlight: true)
    }
}

private extension ArchiveAllPhotosFeature.State {
    mutating func updateVisiblePhotos() {
        visiblePhotos = isSelectedFavorite ? photos.filter(\.isFavorite) : Array(photos)
        lastVisiblePhotoID = visiblePhotos.last?.id
    }

    mutating func updateVisiblePhoto(id: PhotoEntity.ID) {
        guard isSelectedFavorite == false else {
            updateVisiblePhotos()
            return
        }
        guard let photo = photos[id: id],
              let index = visiblePhotos.firstIndex(where: { $0.id == id })
        else { return }
        visiblePhotos[index] = photo
    }
}
