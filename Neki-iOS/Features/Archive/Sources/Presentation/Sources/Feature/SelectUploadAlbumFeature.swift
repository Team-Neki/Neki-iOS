//
//  SelectUploadAlbumFeature.swift
//  Neki-iOS
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
        var viewMode: ViewMode
        var isLoading: Bool
        var appGroupID: String?
        
        var albumSelection: AlbumSelectionFeature.State?
        
        init(pendingUploadImages: [ImageUploadEntity], appGroupID: String? = nil, viewMode: ViewMode = .prompt, isLoading: Bool = false) {
            self.pendingUploadImages = pendingUploadImages
            self.viewMode = viewMode
            self.isLoading = isLoading
            self.appGroupID = appGroupID
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case tapUploadWithoutAlbum
        case tapSelectAlbumAndUpload
        case tapDimmedBackground
        
        case executeUpload(albumId: Int?)
        case uploadResponse(Result<Int?, Error>)
        
        case albumSelection(AlbumSelectionFeature.Action)
        
        case delegate(DelegateAction)
        enum DelegateAction {
            case uploadDidSuccess(albumId: Int?)
            case uploadDidFail(Error)
        }
    }
    
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.sharedImageClient) var sharedImageClient
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.analyticsClient) var analyticsClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .tapDimmedBackground: return .run { [appGroupID = state.appGroupID] _ in
                if let appGroupID {
                    try? await sharedImageClient.clearSharedImages(appGroupID)
                }
                await self.dismiss()
            }
                
            case .tapUploadWithoutAlbum:
                state.isLoading = true
                return .send(.executeUpload(albumId: nil))
                
            case .tapSelectAlbumAndUpload:
                state.viewMode = .albumList
                state.albumSelection = AlbumSelectionFeature.State(
                    photoIDs: [],
                    uploadCount: state.pendingUploadImages.count,
                    selectionPurpose: .upload,
                    currentAlbumId: nil
                )
                return .none
                
            case let .albumSelection(.delegate(.didSelectForUpload(albumId))):
                state.isLoading = true
                return .send(.executeUpload(albumId: albumId))
                
            case .albumSelection(.delegate(.didTapCancel)):
                state.viewMode = .prompt
                state.albumSelection = nil
                return .none
                
            case let .executeUpload(albumId):
                return .run { [entities = state.pendingUploadImages] send in
                    await send(.uploadResponse(
                        Result {
                            let mediaIds = try await imageUploadClient.upload(entities, .photoBooth)
                            let uploads = mediaIds.map { (mediaID: $0, memo: String?.none, uploadMethod: PhotoUploadMethod.direct) }
                            try await archiveClient.registerPhotos(folderId: albumId, uploads: uploads, favorite: false)
                            return albumId
                        }
                    ))
                }
                
            case let .uploadResponse(.success(albumId)):
                state.isLoading = false
                let count = state.pendingUploadImages.count
                return .merge(
                    .run { _ in await analyticsClient.logEvent(ArchiveAnalyticsEvent.photoUpload(method: .direct, count: count)) },
                    .send(.delegate(.uploadDidSuccess(albumId: albumId)))
                )
                
            case let .uploadResponse(.failure(error)):
                state.isLoading = false
                return .send(.delegate(.uploadDidFail(error)))
                
            case .binding, .albumSelection:
                return .none
                
            default: return .none
            }
        }
        .ifLet(\.albumSelection, action: \.albumSelection) {
            AlbumSelectionFeature()
        }
    }
}
