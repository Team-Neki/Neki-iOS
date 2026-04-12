//
//  PhotoImportFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 4/3/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct PhotoImportFeature {
    @ObservableState
    struct State {
        var albums: IdentifiedArrayOf<AlbumItem> = []
        var selectedAlbum: AlbumItem? = nil
        
        var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        var selectedIDs: Set<Int> = []
        
        var isDropdownOpen: Bool = false
        var isFetchingPhotos: Bool = false
        var isFetchingAlbums: Bool = false
        var isLoading: Bool = false
        
        var targetAlbumId: Int 
        
        var uploadCount: Int { selectedIDs.count }
        var isUploadEnabled: Bool { uploadCount > 0 }
        
        init(targetAlbumId: Int) {
            self.targetAlbumId = targetAlbumId
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onAppear
        case fetchAlbumsResponse(Result<[AlbumItem], Error>)
        case fetchFavoriteAlbumResponse(Result<AlbumItem, Error>)
        
        case fetchPhotos
        case loadMorePhotos
        case fetchPhotosResponse(Result<[PhotoEntity], Error>)
        
        case toggleDropdown
        case closeDropdown
        case selectAlbum(AlbumItem?)
        case toggleSelection(Int)
        
        case tapClose
        case tapUpload
        
        case taskCompleted(message: String)
        case taskFailed(message: String)
        
        case delegate(DelegateAction)
        enum DelegateAction {
            case didCompleteTask(message: String)
            case didTapCancel
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.archiveClient) var archiveClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isFetchingAlbums = true
                return .merge(
                    .run { send in
                        do {
                            let entity = try await archiveClient.getFavoriteAlbumInfo()
                            let favoriteAlbum = AlbumItem(id: -1, title: "즐겨찾기", count: entity.totalCount, coverImageURL: URL(string: entity.latestImageURL), isFavorite: true)
                            await send(.fetchFavoriteAlbumResponse(.success(favoriteAlbum)))
                        } catch {
                            await send(.fetchFavoriteAlbumResponse(.failure(error)))
                        }
                    },
                    .run { send in
                        await send(.fetchAlbumsResponse(Result {
                            let entities = try await archiveClient.getAlbumList()
                            return entities.map { AlbumItem(id: $0.id, title: $0.name, count: $0.photoCount, coverImageURL: URL(string: $0.coverImageURLString), isFavorite: false) }
                        }))
                    },
                    .send(.fetchPhotos)
                )
                
            case let .fetchFavoriteAlbumResponse(.success(album)):
                state.albums.removeAll(where: { $0.isFavorite })
                state.albums.insert(album, at: 0)
                return .none
                
            case .fetchFavoriteAlbumResponse(.failure):
                return .none
                
            case let .fetchAlbumsResponse(.success(fetchedAlbums)):
                state.isFetchingAlbums = false
                let favorite = state.albums.first(where: { $0.isFavorite })
                var newAlbums: [AlbumItem] = []
                if let fav = favorite { newAlbums.append(fav) }
                newAlbums.append(contentsOf: fetchedAlbums)
                
                state.albums = IdentifiedArray(uniqueElements: newAlbums)
                return .none
                
            case .fetchAlbumsResponse(.failure):
                state.isFetchingAlbums = false
                return .none
                
            case .fetchPhotos:
                guard !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                let targetFolderId = state.selectedAlbum?.id == -1 ? nil : state.selectedAlbum?.id
                let sortOrder = "DESC"
                
                return .run { [id = state.selectedAlbum?.id] send in
                    if id == -1 {
                        await send(.fetchPhotosResponse(Result { try await archiveClient.fetchFavoritePhotoList(20, sortOrder) }))
                    } else {
                        await send(.fetchPhotosResponse(Result { try await archiveClient.fetchPhotoList(folderId: targetFolderId, size: 20, sortOrder: sortOrder) }))
                    }
                }
                
            case .loadMorePhotos:
                return .send(.fetchPhotos)
                
            case let .fetchPhotosResponse(.success(entities)):
                state.isFetchingPhotos = false
                let currentAlbumId = state.selectedAlbum?.id
                let newItems = entities.map { entity in
                    ArchiveImageItem(id: entity.photoID, imageURLString: entity.imageURL, isFavorite: entity.isfavorite, date: entity.createdAt.toISO8601Date(), folderId: currentAlbumId, memo: entity.memo ?? "", width: entity.width, height: entity.height)
                }
                state.photos = IdentifiedArray(uniqueElements: newItems)
                return .none
                
            case .fetchPhotosResponse(.failure):
                state.isFetchingPhotos = false
                return .none
                
            case .toggleDropdown:
                state.isDropdownOpen.toggle()
                return .none
                
            case .closeDropdown:
                state.isDropdownOpen = false
                return .none
                
            case let .selectAlbum(album):
                state.selectedIDs.removeAll()
                state.selectedAlbum = album
                state.isDropdownOpen = false
                state.photos.removeAll()
                return .send(.fetchPhotos)
                
            case let .toggleSelection(id):
                if state.selectedIDs.contains(id) {
                    state.selectedIDs.remove(id)
                } else {
                    state.selectedIDs.insert(id)
                }
                return .none
                
            case .tapClose:
                return .send(.delegate(.didTapCancel))
                
            case .tapUpload:
                guard state.isUploadEnabled else { return .none }
                state.isLoading = true
                let ids = Array(state.selectedIDs)
                let targetId = state.targetAlbumId
                
                return .run { send in
                    // TODO: 실제 API 연동 (archiveClient.duplicatePhoto(sourceFolderId: nil, photoIDs: ids, targetFolderIDs: [targetId]))
                    try? await Task.sleep(for: .seconds(1)) // 임시 딜레이
                    
                    await send(.taskCompleted(message: "사진을 앨범에 가져왔어요"))
                }
                
            case let .taskCompleted(message):
                state.isLoading = false
                return .send(.delegate(.didCompleteTask(message: message)))
                
            case let .taskFailed(message):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem(message, style: .error))))
                
            case .binding, .delegate:
                return .none
            }
        }
    }
}
