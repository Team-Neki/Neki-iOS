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
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        let album: AlbumItem
        
        var showDropDownMenu: Bool = false
        
        var selectedIDs: Set<Int> = []
        var isSelectionMode: Bool = false
        
        var imagePicker = ImagePickerFeature.State(maxCount: 10, mediaType: .photoBooth)
        var isLoading: Bool = false
        
        var isFetchingPhotos: Bool = false
        
        var hasSelectedItems: Bool { !selectedIDs.isEmpty }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onAppear
        
        case toggleDropDownMenu
        case closeDropDownMenu
        
        case fetchFavoritePhotos
        case favoritePhotoListResponse(Result<[PhotoEntity], Error>)
        case loadMorePhotos
        
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        
        // 기능 액션
        case onTapDownloadButton
        case downloadImagesResponse(successCount: Int)
        
        case imagePicker(ImagePickerFeature.Action)
        case selectUploadAlbum(PresentationAction<SelectUploadAlbumFeature.Action>)
        case processUploadImages(imageIDs: [Int])
        case registerPhotos(imageIDs: [Int])
        case registerPhotosResponse(Result<Void, Error>)
        
        case onTapDeleteButton
        case deletePhotos
        case deletePhotosResponse(Result<Void, Error>)
        
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
        
        Scope(state: \.imagePicker, action: \.imagePicker) {
            ImagePickerFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case .onAppear:
                return .send(.fetchFavoritePhotos)
                
            case .toggleDropDownMenu:
                state.showDropDownMenu.toggle()
                return .none
                
            case .closeDropDownMenu:
                state.showDropDownMenu = false
                return .none
                
                // MARK: - Image Upload
                
            case .imagePicker(.uploadStarted):
                state.isLoading = true
                return .send(.closeDropDownMenu)
                
            case let .imagePicker(.uploadCompleted(ids)):
                return .send(.processUploadImages(imageIDs: ids))
                
            case .imagePicker(.uploadFailed):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("업로드에 실패했어요", style: .error))))
                
            case let .processUploadImages(imageIDs):
                state.isLoading = false
                guard !imageIDs.isEmpty else { return .none }
                return .send(.registerPhotos(imageIDs: imageIDs))
                
            case let .registerPhotos(imageIDs):
                return .run { [mediaIds = imageIDs] send in
                    await send(.registerPhotosResponse(
                        Result {
                            let uploads = mediaIds.map { (mediaID: $0, memo: String?.none) }
                            try await archiveClient.registerPhotos(
                                folderId: nil,
                                uploads: uploads
                            )
                        }
                    ))
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
                    await send(.favoritePhotoListResponse(
                        Result {
                            try await archiveClient.fetchFavoritePhotoList(20, "DESC")
                        }
                    ))
                }
                
            case let .favoritePhotoListResponse(.success(result)):
                state.isFetchingPhotos = false
                
                let currentAlbumId = state.album.id
                
                let newItems = result.map { entity in
                    ArchiveImageItem(
                        id: entity.photoID,
                        imageURLString: entity.imageURL,
                        isFavorite: true,
                        date: entity.createdAt.toISO8601Date(),
                        folderId: currentAlbumId
                    )
                }
                
                state.photos = IdentifiedArray(uniqueElements: newItems)
                return .none
                
            case .favoritePhotoListResponse(.failure):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                return .send(.fetchFavoritePhotos)
                
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
                    if state.selectedIDs.contains(item.id) {
                        state.selectedIDs.remove(item.id)
                    } else {
                        state.selectedIDs.insert(item.id)
                    }
                }
                return .none
                
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
                
            case .onTapDeleteButton:
                guard !state.selectedIDs.isEmpty else { return .none }
                return .send(.deletePhotos)
                
            case .deletePhotos:
                let idsToDelete = Array(state.selectedIDs)
                return .run { send in
                    await send(.deletePhotosResponse(Result {
                        try await archiveClient.deletePhotoList(idsToDelete)
                    }))
                }
                
            case .deletePhotosResponse(.success):
                let idsToRemove = state.selectedIDs
                state.photos.removeAll { idsToRemove.contains($0.id) }
                
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
