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
        var albums: IdentifiedArrayOf<AlbumItem> = []
        
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
        
        case onAppear
        case onTapBackButton
        
        case onTapAlbum(AlbumItem)
        
        case onTapEnterDeleteMode
        case onTapExitDeleteMode
        case onTapToggleSelection(AlbumItem)
        
        // 앨범 삭제 액션
        case onTapExecuteDelete(option: ArchiveAlbumDeleteOption)
        case deleteFoldersResponse(Result<Void, Error>)
        
        // 앨범 생성 액션
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        case addFolderResponse(Result<Int, Error>)
        
        // 앨범 목록 갱신 Action
        case fetchAlbums
        case albumListResponse(Result<[AlbumItem], Error>)
        case favoriteAlbumResponse(Result<AlbumItem, Error>)
        
        // Delegate (부모 코디네이터로 전달)
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.analyticsClient) var analyticsClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
            case .onAppear:
                return .send(.fetchAlbums)
                
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
                let idsToDelete = Array(state.selectedAlbumIDs)
                
                return .run { send in
                    await send(.deleteFoldersResponse(Result {
                        try await archiveClient.deleteFolders(idsToDelete, shouldDeletePhotos)
                    }))
                }
                
            case .deleteFoldersResponse(.success):
                let idsToRemove = state.selectedAlbumIDs
                state.albums.removeAll { idsToRemove.contains($0.id) }
                
                state.isSelectMode = false
                state.selectedAlbumIDs.removeAll()
                
                let toastItem = NekiToastItem("앨범을 삭제했어요", style: .success)
                
                return .merge(
                    .send(.delegate(.showToast(toastItem))),
                    .send(.fetchAlbums)
                )
                
            case .deleteFoldersResponse(.failure):
                let toastItem = NekiToastItem("앨범을 삭제하지 못했어요", style: .error)
                return .send(.delegate(.showToast(toastItem)))
                
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
                    .run { _ in await analyticsClient.logEvent(ArchiveAnalyticsEvent.albumCreate) },
                    .send(.delegate(.showToast(toastItem))),
                    .send(.fetchAlbums)
                )
                
            case .addFolderResponse(.failure):
                let toastItem = NekiToastItem("앨범을 만들지 못했어요", style: .error)
                return .send(.delegate(.showToast(toastItem)))
                
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
                        await send(.albumListResponse(Result {
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
                
            case let .albumListResponse(.success(fetchedAlbums)):
                let favorite = state.albums.first(where: { $0.isFavorite })
                var newAlbums: [AlbumItem] = []
                if let fav = favorite { newAlbums.append(fav) }
                newAlbums.append(contentsOf: fetchedAlbums)
                
                state.albums = IdentifiedArray(uniqueElements: newAlbums)
                return .none
                
            case .albumListResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("앨범을 불러오지 못했어요", style: .error))))
                
                
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
