//
//  AlbumSelectionFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 4/2/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AlbumSelectionFeature {
    @ObservableState
    struct State {
        var albums: IdentifiedArrayOf<AlbumItem> = []
        var selectedAlbumId: Int? = nil
        var uploadCount: Int
        var isFetching: Bool = false
        
        // 앨범 생성관련
        var newAlbumTitle: String = ""
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
        
        init(uploadCount: Int = 1) {
            self.uploadCount = uploadCount
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // 생명주기 및 네트워크
        case onAppear
        case fetchFavoriteAlbumResponse(Result<AlbumItem, Error>)
        case fetchAlbumsResponse(Result<[AlbumItem], Error>)
        
        // 사용자 액션
        case tapBack
        case tapAlbum(Int)
        case tapConfirm
        
        // 앨범 생성 액션
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        case addFolderResponse(Result<Int, Error>)
        
        case delegate(DelegateAction)
        enum DelegateAction {
            case didSelectAlbum(albumId: Int)
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
                state.isFetching = true
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
                    }
                )
                
            case let .fetchFavoriteAlbumResponse(.success(album)):
                state.albums.removeAll(where: { $0.isFavorite })
                state.albums.insert(album, at: 0)
                return .none
                
            case .fetchFavoriteAlbumResponse(.failure):
                return .none
                
            case let .fetchAlbumsResponse(.success(fetchedAlbums)):
                state.isFetching = false
                let favorite = state.albums.first(where: { $0.isFavorite })
                var newAlbums: [AlbumItem] = []
                if let fav = favorite { newAlbums.append(fav) }
                newAlbums.append(contentsOf: fetchedAlbums)
                state.albums = IdentifiedArray(uniqueElements: newAlbums)
                return .none
                
            case .fetchAlbumsResponse(.failure):
                state.isFetching = false
                return .none
                
            case .tapBack:
                return .send(.delegate(.didTapCancel))
                
            case let .tapAlbum(id):
                // 즐겨찾기 앨범은 선택 불가하게
                guard id != -1 else { return .none }
                
                if state.selectedAlbumId == id {
                    state.selectedAlbumId = nil
                } else {
                    state.selectedAlbumId = id
                }
                return .none
                
            case .tapConfirm:
                guard let id = state.selectedAlbumId else { return .none }
                return .send(.delegate(.didSelectAlbum(albumId: id)))
                
                // MARK: - 앨범 생성 관련 처리
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
                return .merge(
                    .send(.delegate(.showToast(NekiToastItem("새로운 앨범을 추가했어요", style: .success)))),
                    .send(.onAppear) // 앨범 목록 갱신
                )
                
            case .addFolderResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("앨범을 만들지 못했어요", style: .error))))
                
            case .binding(\.newAlbumTitle):
                let inputTitle = state.newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if state.albums.contains(where: { $0.title == inputTitle }) {
                    state.albumTitleErrorMessage = "이미 사용 중인 앨범명이에요."
                } else {
                    state.albumTitleErrorMessage = nil
                }
                return .none
                
            case .binding, .delegate:
                return .none
            }
        }
    }
}
