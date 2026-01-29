//
//  ArchiveAllAlbumsFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/20/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ArchiveAllAlbumsFeature {
    
    @ObservableState
    struct State {
        @Shared var albums: IdentifiedArrayOf<AlbumItem>
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        
        var isSelectMode: Bool = false
        var selectedAlbumIDs: Set<Int> = []
        
        var newAlbumTitle: String = ""
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onTapBackButton
        
        case onTapAlbum(AlbumItem)
        
        case onTapEnterDeleteMode
        case onTapExitDeleteMode
        case onTapToggleSelection(AlbumItem)
        
        // 앨범 삭제 액션
        case onTapExecuteDelete(option: ArchiveAlbumDeleteOption)
        case deleteFoldersResponse(Result<Void, Error>)
        
        case fetchPhotos
        case photoListResponse(Result<[ArchiveImageItem], Error>)
        
        // 앨범 생성 액션
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        case addFolderResponse(Result<Int, Error>)
        
        // 앨범 목록 갱신 Action
        case fetchAlbums
        case albumListResponse(Result<[AlbumItem], Error>)
        
        // Delegate (부모 코디네이터로 전달)
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.archiveClient) var archiveClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce {
            state,
            action in
            switch action {
            case .onTapBackButton:
                if state.isSelectMode {
                    return .send(.onTapExitDeleteMode)
                } else {
                    return .run { _ in await dismiss() }
                }
                
            case .onTapEnterDeleteMode:
                state.isSelectMode = true
                state.selectedAlbumIDs.removeAll()
                return .none
                
            case .onTapExitDeleteMode:
                state.isSelectMode = false
                state.selectedAlbumIDs.removeAll()
                return .none
                
            case let .onTapToggleSelection(album):
                guard !album.isFavorite else { return .none }
                
                if state.selectedAlbumIDs.contains(album.id) {
                    state.selectedAlbumIDs.remove(album.id)
                } else {
                    state.selectedAlbumIDs.insert(album.id)
                }
                return .none
                
            case let .onTapExecuteDelete(option):
                guard !state.selectedAlbumIDs.isEmpty else {
                    return .send(.onTapExitDeleteMode)
                }
                
                let shouldDeletePhotos = (option == .withPhotos)
                
                return .run { [ids = state.selectedAlbumIDs] send in
                    await send(.deleteFoldersResponse(Result {
                        try await archiveClient.deleteFolders(folderIDs: Array(ids), deletePhotos: shouldDeletePhotos)
                    }))
                }
                
            case .deleteFoldersResponse(.success):
                state.$albums.withLock { albums in
                    albums.removeAll { state.selectedAlbumIDs.contains($0.id) }
                }
                state.isSelectMode = false
                state.selectedAlbumIDs.removeAll()
                
                let toastItem = NekiToastItem("앨범을 삭제했어요", style: .success)
                
                return .merge(
                    .send(.delegate(.showToast(toastItem))),
                    .send(.fetchAlbums),
                    .send(.fetchPhotos)
                )
                
            case .deleteFoldersResponse(.failure):
                let toastItem = NekiToastItem("앨범을 삭제하지 못했어요", style: .error)
                return .send(.delegate(.showToast(toastItem)))
                
            case .fetchPhotos:
                return .run { send in
                    await send(.photoListResponse(Result {
                        let result = try await archiveClient.fetchPhotoList(folderId: nil, page: 0, size: 20, sortOrder: nil)
                        
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        return result.photos.map { entity in
                            ArchiveImageItem(
                                id: entity.photoID,
                                imageURLString: entity.imageURL,
                                isFavorite: entity.isfavorite,
                                date: isoFormatter.date(from: entity.createdAt) ?? Date()
                            )
                        }
                    }))
                }
                
            case let .photoListResponse(.success(newPhotos)):
                state.$photos.withLock { sharedPhotos in
                    sharedPhotos = IdentifiedArray(uniqueElements: newPhotos)
                }
                return .none
                
            case .photoListResponse(.failure):
                return .none
                
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
                        try await archiveClient.addFolder(name: title)
                    }))
                }
                
            case .addFolderResponse(.success):
                let toastItem = NekiToastItem("새로운 앨범을 추가했어요", style: .success)
                
                return .merge(
                    .send(.delegate(.showToast(toastItem))),
                    .send(.fetchAlbums)
                )
                
            case .addFolderResponse(.failure):
                let toastItem = NekiToastItem("앨범을 만들지 못했어요", style: .error)
                return .send(.delegate(.showToast(toastItem)))
                
            case .fetchAlbums:
                return .run { send in
                    await send(
                        .albumListResponse(
                            Result {
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
                            })
                    )
                }
                
            case let .albumListResponse(.success(newAlbums)):
                state.$albums.withLock { existing in
                    var favoriteAlbum: AlbumItem?
                    if let first = existing.first,
                       first.isFavorite {
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
                
                
                // MARK: - Binding Action
                
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
    }
}
