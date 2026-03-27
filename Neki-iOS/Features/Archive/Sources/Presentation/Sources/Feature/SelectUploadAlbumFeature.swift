//
//  SelectUploadAlbumFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct SelectUploadAlbumFeature {
    
    enum ViewMode: Equatable {
        case prompt
        case albumList
    }
    
    @ObservableState
    struct State {
        let pendingUploadImages: [ImageUploadEntity]
        var albums: IdentifiedArrayOf<AlbumItem>
        var selectedAlbumId: Int? = nil
        var viewMode: ViewMode = .prompt
        var isLoading: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case tapUploadWithoutAlbum
        case tapSelectAlbumAndUpload
        case tapBackToPrompt
        case tapAlbum(AlbumItem)
        case tapConfirmUpload
        
        case executeUpload(albumId: Int?)
        case uploadResponse(Result<Int?, Error>)
        
        case delegate(DelegateAction)
        enum DelegateAction {
            case uploadDidSuccess(albumId: Int?)
            case uploadDidFail(Error)
        }
    }
    
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.imageUploadClient) var imageUploadClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .tapUploadWithoutAlbum:
                state.isLoading = true
                return .send(.executeUpload(albumId: nil))
                
            case .tapSelectAlbumAndUpload:
                state.viewMode = .albumList
                return .none
                
            case .tapBackToPrompt:
                state.viewMode = .prompt
                return .none
                
            case let .tapAlbum(album):
                state.selectedAlbumId = (state.selectedAlbumId == album.id) ? nil : album.id
                return .none
                
            case .tapConfirmUpload:
                guard let albumId = state.selectedAlbumId else { return .none }
                state.isLoading = true
                return .send(.executeUpload(albumId: albumId))
                
            case let .executeUpload(albumId):
                return .run { [entities = state.pendingUploadImages] send in
                    await send(.uploadResponse(
                        Result {
                            let mediaIds = try await imageUploadClient.upload(entities, .photoBooth)
                            let uploads = mediaIds.map { (mediaID: $0, memo: String?.none, uploadMethod: PhotoUploadMethod.qr) }
                            try await archiveClient.registerPhotos(folderId: albumId, uploads: uploads, favorite: false)
                            return albumId
                        }
                    ))
                }
                
            case let .uploadResponse(.success(albumId)):
                state.isLoading = false
                return .send(.delegate(.uploadDidSuccess(albumId: albumId)))
                
            case let .uploadResponse(.failure(error)):
                state.isLoading = false
                return .send(.delegate(.uploadDidFail(error)))
                
            case .binding:
                return .none
                
            default:
                return .none
            }
        }
    }
}
