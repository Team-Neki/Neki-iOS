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
        @Presents var albumSelection: AlbumSelectionFeature.State?
        
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        let album: AlbumItem
        var showDropDownMenu: Bool = false
        var selectedIDs: Set<Int> = []
        var isSelectionMode: Bool = false
        var imagePicker = ImagePickerFeature.State(maxCount: 10, mediaType: .photoBooth, autoUpload: false)
        var isLoading: Bool = false
        var isFetchingPhotos: Bool = false
        var hasSelectedItems: Bool { !selectedIDs.isEmpty }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case toggleDropDownMenu
        case closeDropDownMenu
        case onTapFavorite(item: ArchiveImageItem)
        case toggleFavoriteResponse(photoID: Int, result: Result<Void, Error>)
        case fetchFavoritePhotos
        case favoritePhotoListResponse(Result<[PhotoEntity], Error>)
        case loadMorePhotos
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        case onTapDownloadButton
        case downloadImagesResponse(successCount: Int)
        case imagePicker(ImagePickerFeature.Action)
        case processUploadImages(entities: [ImageUploadEntity])
        case registerPhotos(entities: [ImageUploadEntity])
        case registerPhotosResponse(Result<Void, Error>)
        case onTapDeleteButton
        case deletePhotos
        case deletePhotosResponse(Result<Void, Error>)
        case imageTapped(ArchiveImageItem)
        
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
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.imageDownloadClient) var imageDownloadClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) { ImagePickerFeature() }
        
        Reduce { state, action in
            switch action {
            case .onTapBackButton: return .run { _ in await dismiss() }
            case .onAppear: return .send(.fetchFavoritePhotos)
                
            case .toggleDropDownMenu:
                state.showDropDownMenu.toggle()
                return .none
                
            case .closeDropDownMenu:
                state.showDropDownMenu = false
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
                
            case .toggleFavoriteResponse(_, .success): return .none
            case let .toggleFavoriteResponse(photoID, .failure):
                state.photos[id: photoID]?.isFavorite.toggle()
                return .send(.delegate(.showToast(NekiToastItem("즐겨찾기 변경에 실패했어요", style: .error))))
                
            case let .imagePicker(.delegate(.imagesConverted(entities))):
                state.showDropDownMenu = false
                return .send(.processUploadImages(entities: entities))
                
            case let .processUploadImages(entities):
                state.isLoading = false
                guard !entities.isEmpty else { return .none }
                state.isLoading = true
                return .send(.registerPhotos(entities: entities))
                
            case let .registerPhotos(entities):
                return .run { send in
                    await send(.registerPhotosResponse(Result {
                        let mediaIds = try await imageUploadClient.upload(entities, .photoBooth)
                        let uploads = mediaIds.map { (mediaID: $0, memo: String?.none, uploadMethod: PhotoUploadMethod.direct) }
                        try await archiveClient.registerPhotos(folderId: nil, uploads: uploads, favorite: true)
                    }))
                }
                
            case .registerPhotosResponse(.success):
                state.isLoading = false
                return .run { send in
                    await send(.delegate(.showToast(NekiToastItem("이미지를 추가했어요", style: .success))))
                    await send(.fetchFavoritePhotos)
                }
                
            case .registerPhotosResponse(.failure):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("업로드에 실패했어요", style: .error))))
                
            case .fetchFavoritePhotos:
                guard !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                return .run { send in
                    await send(.favoritePhotoListResponse(Result { try await archiveClient.fetchFavoritePhotoList(20, "DESC") }))
                }
                
            case let .favoritePhotoListResponse(.success(result)):
                state.isFetchingPhotos = false
                let currentAlbumId = state.album.id
                let newItems = result.map { entity in
                    ArchiveImageItem(id: entity.photoID, imageURLString: entity.imageURL, isFavorite: true, date: entity.createdAt.toISO8601Date(), folderId: currentAlbumId, memo: entity.memo ?? "", width: entity.width, height: entity.height)
                }
                state.photos = IdentifiedArray(uniqueElements: newItems)
                return .none
                
            case .favoritePhotoListResponse(.failure):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos: return .send(.fetchFavoritePhotos)
                
            case .onTapSelectButton:
                state.showDropDownMenu = false
                state.isSelectionMode = true
                return .none
                
            case .onTapCancelSelectButton:
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .none
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if state.selectedIDs.contains(item.id) { state.selectedIDs.remove(item.id) }
                    else { state.selectedIDs.insert(item.id) }
                }
                return .none
                
            // 💡 캡슐화 적용
            case .onTapDuplicateButton:
                state.albumSelection = AlbumSelectionFeature.State(photoIDs: Array(state.selectedIDs), selectionPurpose: .duplicate, currentAlbumId: state.album.id)
                return .none
                
            case .onTapMoveButton:
                state.albumSelection = AlbumSelectionFeature.State(photoIDs: Array(state.selectedIDs), selectionPurpose: .move, currentAlbumId: state.album.id)
                return .none
                
            case let .albumSelection(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .didCompleteTask(message):
                    state.albumSelection = nil
                    state.isSelectionMode = false
                    state.selectedIDs.removeAll()
                    
                    return .merge(
                        .send(.delegate(.showToast(NekiToastItem(message, style: .success)))),
                        .send(.fetchFavoritePhotos)
                    )
                    
                case .didTapCancel:
                    state.albumSelection = nil
                    return .none
                    
                case let .showToast(toastItem):
                    return .send(.delegate(.showToast(toastItem)))
                    
                case .didSelectForUpload(albumId: _):
                    return .none
                }
                
            case .onTapDownloadButton:
                guard !state.selectedIDs.isEmpty else { return .none }
                return .run { [photos = state.photos, selectedIDs = state.selectedIDs] send in
                    let urls = selectedIDs.compactMap { photos[id: $0]?.imageURL }
                    let count = try await imageDownloadClient.downloadImages(urls: urls)
                    await send(.downloadImagesResponse(successCount: count))
                }
                
            case let .downloadImagesResponse(count):
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                if count > 0 { return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success)))) }
                else { return .send(.delegate(.showToast(NekiToastItem("사진 저장에 실패했어요", style: .error)))) }
                
            case .onTapDeleteButton:
                guard !state.selectedIDs.isEmpty else { return .none }
                return .send(.deletePhotos)
                
            case .deletePhotos:
                let idsToDelete = Array(state.selectedIDs)
                return .run { send in
                    await send(.deletePhotosResponse(Result { try await archiveClient.deletePhotoList(idsToDelete) }))
                }
                
            case .deletePhotosResponse(.success):
                let idsToRemove = state.selectedIDs
                state.photos.removeAll { idsToRemove.contains($0.id) }
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
            case .deletePhotosResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제하지 못했어요", style: .error))))
                
            default: return .none
            }
        }
        .ifLet(\.$albumSelection, action: \.albumSelection) { AlbumSelectionFeature() }
    }
}
