//
//  ArchiveFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import os

@Reducer
struct ArchiveFeature {
    
    @ObservableState
    struct State {
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        var albums: IdentifiedArrayOf<AlbumItem> = []
        
        var previewAlbums: IdentifiedArrayOf<AlbumItem> {
            return IdentifiedArray(uniqueElements: albums.prefix(5))
        }
        
        @Shared(.appStorage("showTooltip")) var showTooltip: Bool = true
        @Presents var selectUploadAlbum: SelectUploadAlbumFeature.State?
        
        var newAlbumTitle: String = ""
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
        
        var imagePicker = ImagePickerFeature.State(maxCount: 10, mediaType: .photoBooth)
        var isLoading: Bool = false
        
        var isFetchingPhotos: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case clearData
        
        // View Life Cycle Action
        case onAppear
        
        // User Action
        case onTapAllPhotos
        case onTapAllAlbums
        case openAppSettings
        
        // Add Folder Action
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        case addFolderResponse(Result<Int, Error>)
        
        // QR Scanner Action
        case onTapQRScan
        
        // Fetch Actions
        case fetchAlbums
        case fetchPhotos
        
        // Responses
        case albumsResponse(Result<[AlbumItem], Error>)
        case favoriteAlbumResponse(Result<AlbumItem, Error>)
        case photoListResponse(Result<[PhotoEntity], Error>)
        
        // Image Upload Action
        case imagePicker(ImagePickerFeature.Action)
        case selectUploadAlbum(PresentationAction<SelectUploadAlbumFeature.Action>)
        
        // Pagination
        case loadMorePhotos
        
        // Navigation Action
        case imageTapped(ArchiveImageItem)
        case albumTapped(AlbumItem)
        case afterUploadNavigateToAlbumDetail(AlbumItem)
        
        // Internal Action
        case addPhotoFromQRScanner(imageID: Int)
        case processUploadImages(imageIDs: [Int])
        
        // Delegate Action
        case delegate(DelegateAction)
        enum DelegateAction {
            case showToast(NekiToastItem)
            case requestQRScan
        }
    }
    
    @Dependency(\.archiveClient) var archiveClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) {
            ImagePickerFeature()
        }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                
            case .clearData:
                state.photos.removeAll()
                state.albums.removeAll()
                return .none
                
                // MARK: - View Life Cycle Action
                
            case .onAppear:
                return .merge(
                    .send(.fetchAlbums),
                    .send(.fetchPhotos)
                )
                
                // MARK: - Add Folder Action
                
            case .onTapCancelAddAlbum:
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                return .none
                
            case .onTapConfirmAddAlbum:
                guard state.isConfirmButtonEnabled else { return .none }
                let title = state.newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                
                return .run { send in
                    await send(.addFolderResponse(Result {
                        try await archiveClient.addFolder(title)
                    }))
                }
                
            case .addFolderResponse(.success):
                return .run { send in
                    await send(.delegate(.showToast(NekiToastItem("새로운 앨범을 추가했어요", style: .success))))
                    await send(.fetchAlbums)
                }
                
            case .addFolderResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("앨범을 만들지 못했어요", style: .error))))
                
                // MARK: - QR Scanner Action
                
            case .onTapQRScan:
                return .send(.delegate(.requestQRScan))
                
                // MARK: - Fetch Logic
                
            case .fetchAlbums:
                return .merge(
                    .run { send in
                        do {
                            let entity = try await archiveClient.getFavoriteAlbumInfo()
                            let favoriteAlbum = AlbumItem(
                                id: 0,
                                title: "즐겨찾기",
                                count: entity.totalCount,
                                coverImageURL: URL(string: entity.latestImageURL),
                                isFavorite: true
                            )
                            await send(.favoriteAlbumResponse(.success(favoriteAlbum)))
                        } catch {
                            await send(.favoriteAlbumResponse(.failure(error)))
                        }
                    },
                    .run { send in
                        await send(.albumsResponse(Result {
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
                )
                
            case let .favoriteAlbumResponse(.success(album)):
                state.albums.removeAll(where: { $0.isFavorite })
                state.albums.insert(album, at: 0)
                return .none
                
            case .favoriteAlbumResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("즐겨찾기 앨범을 불러오지 못했어요", style: .error))))
                
            case let .albumsResponse(.success(fetchedAlbums)):
                let favorite = state.albums.first(where: { $0.isFavorite })
                var newAlbums: [AlbumItem] = []
                if let fav = favorite { newAlbums.append(fav) }
                newAlbums.append(contentsOf: fetchedAlbums)
                
                state.albums = IdentifiedArray(uniqueElements: newAlbums)
                return .none
                
            case .albumsResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("앨범을 불러오지 못했어요", style: .error))))
                
                
                // MARK: - Fetch Photos
                
            case .fetchPhotos:
                guard !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                
                return .run { send in
                    await send(.photoListResponse(Result {
                        let photos = try await archiveClient.fetchPhotoList(nil, nil, nil)
                        return photos
                    }))
                }
                
            case let .photoListResponse(.success(entities)):
                state.isFetchingPhotos = false
                
                let items = entities.map { entity in
                    ArchiveImageItem(
                        id: entity.photoID,
                        imageURLString: entity.imageURL,
                        isFavorite: entity.isfavorite,
                        date: entity.createdAt.toISO8601Date()
                    )
                }
                
                state.photos = IdentifiedArray(uniqueElements: items)
                return .none
                
            case .photoListResponse(.failure):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                return .send(.fetchPhotos)
                
                // MARK: - Image Upload
                
            case .imagePicker(.uploadStarted):
                state.isLoading = true
                return .none
                
            case let .imagePicker(.uploadCompleted(ids)):
                return .send(.processUploadImages(imageIDs: ids))
                
            case let .processUploadImages(imageIDs):
                state.isLoading = false
                guard !imageIDs.isEmpty else { return .none }
                state.selectUploadAlbum = SelectUploadAlbumFeature.State(uploadedImageIds: imageIDs, albums: state.albums)
                return .none
                
            case let .selectUploadAlbum(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .uploadDidSuccess(albumId):
                    state.selectUploadAlbum = nil
                    
                    if let albumId = albumId, let album = state.albums.first(where: { $0.id == albumId }) {
                        return .run { send in
                            await send(.delegate(.showToast(NekiToastItem("이미지를 추가했어요", style: .success))))
                            await send(.fetchPhotos)
                            await send(.fetchAlbums)
                            try? await Task.sleep(for: .milliseconds(400))
                            await send(.afterUploadNavigateToAlbumDetail(album))
                        }
                    }
                    
                    return .run { send in
                        await send(.delegate(.showToast(NekiToastItem("이미지를 추가했어요", style: .success))))
                        await send(.fetchPhotos)
                        await send(.fetchAlbums)
                    }
                    
                case .uploadDidFail:
                    state.selectUploadAlbum = nil
                    return .send(.delegate(.showToast(NekiToastItem("업로드에 실패했어요", style: .error))))
                }
                
            case .imagePicker(.uploadFailed):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("업로드에 실패했어요", style: .error))))
                
            case let .addPhotoFromQRScanner(imageID):
                return .run { send in
                    try await archiveClient.registerPhotos(nil, [(imageID, nil)])
                    await send(.delegate(.showToast(NekiToastItem("이미지를 추가했어요", style: .success))))
                    await send(.fetchPhotos)
                } catch: { error, send in
                    Logger.presentation.error("사진 등록 실패: \(error)")
                    await send(.delegate(.showToast(NekiToastItem("사진 등록에 실패했어요", style: .error))))
                }
                
                // MARK: - Binding
                
            case .binding(\.newAlbumTitle):
                let inputTitle = state.newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if state.albums.contains(where: { $0.title == inputTitle }) {
                    state.albumTitleErrorMessage = "이미 사용 중인 앨범명이에요."
                } else {
                    state.albumTitleErrorMessage = nil
                }
                return .none
                
            default:
                return .none
            }
        }
        .ifLet(\.$selectUploadAlbum, action: \.selectUploadAlbum) {
            SelectUploadAlbumFeature()
        }
    }
}
