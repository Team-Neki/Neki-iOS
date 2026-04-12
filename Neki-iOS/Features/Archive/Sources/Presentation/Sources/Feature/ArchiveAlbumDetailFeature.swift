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
        @Presents var albumSelection: AlbumSelectionFeature.State?
        @Presents var photoImport: PhotoImportFeature.State?
        var selectionPurpose: PhotoSelectionPurpose?
        
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        let album: AlbumItem
        var showDropDownMenu: Bool = false
        var selectedIDs: Set<Int> = []
        
        var newAlbumTitle: String = ""
        var albumTitleErrorMessage: String? = nil
        var isConfirmButtonEnabled: Bool {
            let trimmed = newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed != album.title && albumTitleErrorMessage == nil
        }
        
        var isSelectionMode: Bool = false
        var filteredAlbumPhotos: IdentifiedArrayOf<ArchiveImageItem> { return photos }
        var isFetchingPhotos: Bool = false
        var imagePicker = ImagePickerFeature.State(maxCount: 10, mediaType: .photoBooth, autoUpload: false)
        var isLoading: Bool = false
        var hasSelectedItems: Bool { !selectedIDs.isEmpty }
        
        init(photos: IdentifiedArrayOf<ArchiveImageItem> = [], album: AlbumItem) {
            self.photos = photos
            self.album = album
            self.newAlbumTitle = album.title
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case toggleDropDownMenu
        case closeDropDownMenu
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        case onTapFavorite(item: ArchiveImageItem)
        case toggleFavoriteResponse(photoID: Int, result: Result<Void, Error>)
        case onTapCancelEditAlbum
        case onTapConfirmEditAlbum
        case editAlbumResponse(Result<Void, Error>)
        
        case imagePicker(ImagePickerFeature.Action)
        case processUploadImages(entities: [ImageUploadEntity])
        case registerPhotos(entities: [ImageUploadEntity])
        case registerPhotosResponse(Result<Void, Error>)
        
        case onTapDuplicateButton
        case onTapMoveButton
        case albumSelection(PresentationAction<AlbumSelectionFeature.Action>)
        
        case onTapDownloadButton
        case downloadImagesResponse(successCount: Int)
        
        case onTapDeleteButton(option: ArchivePhotoDeleteOption)
        case deletePhotosResponse(Result<Void, Error>)
        
        case onTapExecuteDeleteAlbum(option: ArchiveAlbumDeleteOption)
        case deleteAlbumResponse(Result<Void, Error>)
        
        case onTapImportPhotos
        case photoImport(PresentationAction<PhotoImportFeature.Action>)
        
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
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.imageDownloadClient) var imageDownloadClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) { ImagePickerFeature() }
        
        Reduce { state, action in
            switch action {
            case .onTapBackButton: return .run { _ in await dismiss() }
            case .onAppear: return .send(.fetchPhotos)
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
                let albumId = state.album.id
                return .run { send in
                    await send(.registerPhotosResponse(Result {
                        let mediaIds = try await imageUploadClient.upload(entities, .photoBooth)
                        let uploads = mediaIds.map { (mediaID: $0, memo: String?.none, uploadMethod: PhotoUploadMethod.direct) }
                        try await archiveClient.registerPhotos(folderId: albumId, uploads: uploads ,favorite: false)
                    }))
                }
            case .registerPhotosResponse(.success):
                state.isLoading = false
                return .run { send in
                    await send(.delegate(.showToast(NekiToastItem("이미지를 추가했어요", style: .success))))
                    await send(.fetchPhotos)
                }
            case .registerPhotosResponse(.failure):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("업로드에 실패했어요", style: .error))))
            case .onTapCancelEditAlbum:
                state.newAlbumTitle = state.album.title
                state.albumTitleErrorMessage = nil
                return .none
            case .onTapConfirmEditAlbum:
                guard state.isConfirmButtonEnabled else { return .none }
                let title = state.newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                state.albumTitleErrorMessage = nil
                return .run { [albumId = state.album.id] send in
                    await send(.editAlbumResponse(Result { try await archiveClient.editAlbumName(albumId, title) }))
                }
            case .editAlbumResponse(.success): return .send(.delegate(.showToast(NekiToastItem("앨범 이름을 변경했어요", style: .success))))
            case .editAlbumResponse(.failure):
                state.newAlbumTitle = state.album.title
                return .send(.delegate(.showToast(NekiToastItem("앨범 이름을 변경하지 못했어요", style: .error))))
            case .fetchPhotos:
                state.isFetchingPhotos = true
                return .run { [albumId = state.album.id] send in
                    await send(.photoListResponse(Result { try await archiveClient.fetchPhotoList(folderId: albumId, size: 20, sortOrder: nil) }))
                }
            case let .photoListResponse(.success(entities)):
                state.isFetchingPhotos = false
                let currentAlbumId = state.album.id
                let newItems = entities.map { entity in
                    ArchiveImageItem(id: entity.photoID, imageURLString: entity.imageURL, isFavorite: entity.isfavorite, date: entity.createdAt.toISO8601Date(), folderId: currentAlbumId, memo: entity.memo ?? "", width: entity.width, height: entity.height)
                }
                state.photos = IdentifiedArray(uniqueElements: newItems)
                return .none
            case .photoListResponse(.failure):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
            case .loadMorePhotos: return .send(.fetchPhotos)
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
                        .send(.fetchPhotos)
                    )
                case .didTapCancel:
                    state.albumSelection = nil
                    return .none
                case let .showToast(toastItem):
                    return .send(.delegate(.showToast(toastItem)))
                }
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
            case let .onTapDeleteButton(option):
                guard !state.selectedIDs.isEmpty else { return .none }
                let selectedIDs = Array(state.selectedIDs)
                let albumID = state.album.id
                return .run { send in
                    await send(.deletePhotosResponse(Result {
                        if option == .fromAlbumOnly { try await archiveClient.excludePhotosInAlbum(albumID, selectedIDs) }
                        else { try await archiveClient.deletePhotoList(selectedIDs) }
                    }))
                }
            case .deletePhotosResponse(.success):
                let idsToDelete = state.selectedIDs
                state.photos.removeAll { idsToDelete.contains($0.id) }
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
            case .deletePhotosResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제하지 못했어요", style: .error))))
            case let .onTapExecuteDeleteAlbum(option):
                let shouldDeletePhotos = (option == .withPhotos)
                let albumId = state.album.id
                return .run { send in
                    await send(.deleteAlbumResponse(Result {
                        try await archiveClient.deleteFolders([albumId], shouldDeletePhotos)
                    }))
                }
            case .deleteAlbumResponse(.success):
                return .run { send in
                    await send(.delegate(.showToast(NekiToastItem("앨범을 삭제했어요", style: .success))))
                    await dismiss()
                }
            case .deleteAlbumResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("앨범을 삭제하지 못했어요", style: .error))))
                
            case .onTapImportPhotos:
                state.showDropDownMenu = false
                state.photoImport = PhotoImportFeature.State(targetAlbumId: state.album.id) // 목적지 ID 주입
                return .none
                
            case let .photoImport(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .didCompleteTask(message):
                    state.photoImport = nil
                    return .merge(
                        .send(.delegate(.showToast(NekiToastItem(message, style: .success)))),
                        .send(.fetchPhotos)
                    )
                    
                case .didTapCancel:
                    state.photoImport = nil
                    return .none
                    
                case let .showToast(toastItem):
                    return .send(.delegate(.showToast(toastItem)))
                }
                
            default: return .none
            }
        }
        .ifLet(\.$albumSelection, action: \.albumSelection) { AlbumSelectionFeature() }
        .ifLet(\.$photoImport, action: \.photoImport) { PhotoImportFeature() }
    }
}
