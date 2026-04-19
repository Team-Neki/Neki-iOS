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
        
        var imagePicker = ImagePickerFeature.State(maxCount: 10, mediaType: .photoBooth, autoUpload: false)
        var isLoading: Bool = false
        var isFetchingPhotos: Bool = false
        
        var isInitialFetchingPhotos: Bool {
            return isFetchingPhotos && photos.isEmpty
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case clearData
        case onAppear
        case onTapAllPhotos
        case onTapAllAlbums
        case openAppSettings
        case onTapFavorite(item: ArchiveImageItem)
        case toggleFavoriteResponse(photoID: Int, result: Result<Void, Error>)
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        case addFolderResponse(Result<Int, Error>)
        case onTapQRScan
        case fetchAlbums
        case fetchPhotos
        case albumsResponse(Result<[AlbumItem], Error>)
        case favoriteAlbumResponse(Result<AlbumItem, Error>)
        case photoListResponse(Result<[PhotoEntity], Error>)
        
        case imagePicker(ImagePickerFeature.Action)
        case selectUploadAlbum(PresentationAction<SelectUploadAlbumFeature.Action>)
        
        case loadMorePhotos
        case imageTapped(ArchiveImageItem)
        case albumTapped(AlbumItem)
        case afterUploadNavigateToAlbumDetail(AlbumItem)
        
        case addPhotoFromQRScanner(imageID: Int)
        
        case processUploadImages(entities: [ImageUploadEntity], appGroupID: String?)
        case uploadSharedImagesResponse(Result<[ImageUploadEntity], Error>, appGroupID: String?)
        
        case addPhotoFromShareExtension(appGroupID: String)
        case cleanSharedImages(appGroupID: String)
        
        case delegate(DelegateAction)
        enum DelegateAction {
            case showToast(NekiToastItem)
            case requestQRScan
        }
    }
    
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.sharedImageClient) var sharedImageClient
    @Dependency(\.analyticsClient) var analyticsClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) { ImagePickerFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                
            case .clearData:
                state.photos.removeAll()
                state.albums.removeAll()
                return .run { _ in
                    await archiveClient.clearCache()
                }
                
            case .onAppear:
                return .merge(.send(.fetchAlbums), .send(.fetchPhotos))
                
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
                return .merge(.send(.fetchAlbums), .send(.fetchPhotos))
                
            case let .toggleFavoriteResponse(photoID, .failure):
                state.photos[id: photoID]?.isFavorite.toggle()
                return .send(.delegate(.showToast(NekiToastItem("즐겨찾기 변경에 실패했어요", style: .error))))
                
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
                    await send(.addFolderResponse(Result { try await archiveClient.addFolder(title) }))
                }
                
            case .addFolderResponse(.success):
                analyticsClient.logEvent(ArchiveAnalyticsEvent.albumCreate)
                return .run { send in
                    await send(.delegate(.showToast(NekiToastItem("새로운 앨범을 추가했어요", style: .success))))
                    await send(.fetchAlbums)
                }
                
            case .addFolderResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("앨범을 만들지 못했어요", style: .error))))
                
            case .onTapQRScan: return .send(.delegate(.requestQRScan))
                
            case .fetchAlbums:
                return .merge(
                    .run { send in
                        do {
                            let entity = try await archiveClient.getFavoriteAlbumInfo()
                            let favoriteAlbum = AlbumItem(id: -1, title: "즐겨찾기", count: entity.totalCount, coverImageURL: URL(string: entity.latestImageURL), isFavorite: true)
                            await send(.favoriteAlbumResponse(.success(favoriteAlbum)))
                        } catch {
                            await send(.favoriteAlbumResponse(.failure(error)))
                        }
                    },
                    .run { send in
                        await send(.albumsResponse(Result {
                            let entities = try await archiveClient.getAlbumList()
                            return entities.map { AlbumItem(id: $0.id, title: $0.name, count: $0.photoCount, coverImageURL: URL(string: $0.coverImageURLString), isFavorite: false) }
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
                
            case .fetchPhotos:
                guard !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                return .run { send in
                    await send(.photoListResponse(Result { try await archiveClient.fetchPhotoList(nil, nil, nil) }))
                }
                
            case let .photoListResponse(.success(entities)):
                state.isFetchingPhotos = false
                let items = entities.map { entity in
                    ArchiveImageItem(
                        id: entity.photoID,
                        imageURLString: entity.imageURL,
                        isFavorite: entity.isfavorite,
                        date: entity.createdAt.toISO8601Date(),
                        folderId: entity.folderID,
                        memo: entity.memo ?? "",
                        width: entity.width,
                        height: entity.height
                    )
                }
                state.photos = IdentifiedArray(uniqueElements: items)
                return .none
                
            case .photoListResponse(.failure):
                state.isFetchingPhotos = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos: return .send(.fetchPhotos)
                
            case let .imagePicker(.delegate(.imagesConverted(entities))):
                return .send(.processUploadImages(entities: entities, appGroupID: nil))
                
            case let .processUploadImages(entities, appGroupID):
                state.isLoading = false
                guard !entities.isEmpty else { return .none }
                state.selectUploadAlbum = SelectUploadAlbumFeature.State(pendingUploadImages: entities, appGroupID: appGroupID)
                return .none
                
            case let .addPhotoFromShareExtension(appGroupID):
                state.isLoading = true
                return .run { send in
                    do {
                        let fileURLs = try await sharedImageClient.fetchSharedImageURLs(appGroupID: appGroupID)
                        guard !fileURLs.isEmpty else {
                            await send(.delegate(.showToast(NekiToastItem("가져올 수 있는 이미지가 없어요.", style: .error))))
                            await send(.uploadSharedImagesResponse(.failure(UploadError.uploadFailed), appGroupID: appGroupID))
                            return
                        }
                        
                        var entities: [ImageUploadEntity] = []
                        for url in fileURLs {
                            if let data = try? Data(contentsOf: url) {
                                entities.append(ImageUploadEntity(data: data, format: .jpeg, size: data.count))
                            }
                        }
                        await send(.cleanSharedImages(appGroupID: appGroupID))
                        await send(.uploadSharedImagesResponse(.success(entities), appGroupID: appGroupID))
                    } catch {
                        await send(.cleanSharedImages(appGroupID: appGroupID))
                        await send(.uploadSharedImagesResponse(.failure(error), appGroupID: appGroupID))
                    }
                }
                
            case let .selectUploadAlbum(.presented(.delegate(.uploadDidSuccess(albumId)))):
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
                
            case .selectUploadAlbum(.presented(.delegate(.uploadDidFail))):
                state.selectUploadAlbum = nil
                return .send(.delegate(.showToast(NekiToastItem("업로드에 실패했어요", style: .error))))
                
            case let .addPhotoFromQRScanner(imageID):
                return .run { send in
                    try await archiveClient.registerPhotos(nil, [(imageID, nil, PhotoUploadMethod.qr)], false)
                    await send(.delegate(.showToast(NekiToastItem("이미지를 추가했어요", style: .success))))
                    await send(.fetchPhotos)
                } catch: { error, send in
                    await send(.delegate(.showToast(NekiToastItem("사진 등록에 실패했어요", style: .error))))
                }
                
            case let .cleanSharedImages(appGroupID):
                return .run { send in
                    try? await sharedImageClient.clearSharedImages(appGroupID: appGroupID)
                }
                
            case let .uploadSharedImagesResponse(.success(entities), appGroupID):
                return .send(.processUploadImages(entities: entities, appGroupID: appGroupID))
                
            case .uploadSharedImagesResponse(.failure, _):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("업로드에 실패했어요", style: .error))))
                
            case .binding(\.newAlbumTitle):
                let inputTitle = state.newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                state.albumTitleErrorMessage = state.albums.contains(where: { $0.title == inputTitle }) ? "이미 사용 중인 앨범명이에요." : nil
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
