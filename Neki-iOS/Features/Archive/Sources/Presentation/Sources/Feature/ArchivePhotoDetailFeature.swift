//
//  ArchivePhotoDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct ArchivePhotoDetailFeature {
    @ObservableState
    struct State {
        @Presents var imageTransform: ImageTransformFeature.State?
        @Presents var albumSelection: AlbumSelectionFeature.State?
        
        var photos: IdentifiedArrayOf<PhotoEntity>
        var currentItemID: Int
        let folderId: Int?
        
        var currentItem: PhotoEntity? { photos[id: currentItemID] }
        var formattedDate: String {
            return currentItem?.createdAt.toDotFormatString() ?? ""
        }
        
        var isLoading: Bool = false
        var isMemoVisible: Bool = false
        var isMemoExpanded: Bool = false
        var isMemoEditing: Bool = false
        var editingMemoText: String = ""
        
        var showDropDownMenu: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onAppear
        
        case toggleMemoVisibility
        case toggleMemoExpanded(Bool)
        case startMemoEditing
        case cancelMemoEditing
        case doneMemoEditing
        case clearAllMemoEditing
        case memoUpdateResponse(Result<Void, Error>)
        
        case onTapTransform
        case imageFetchResponse(Result<UIImage, Error>)
        case imageTransform(PresentationAction<ImageTransformFeature.Action>)
        
        case onTapAddToAlbum
        case albumSelection(PresentationAction<AlbumSelectionFeature.Action>)
        
        case onTapBackButton
        case onTapDownload
        case downloadImageResponse(successCount: Int)
        case onTapFavorite
        case toggleFavoriteResponse(photoID: Int, result: Result<Void, Error>)
        case onTapDelete
        case deletePhotoResponse(Result<Void, Error>)
        
        case toggleDropDownMenu
        case closeDropDownMenu
        
        case onTapShareToInstagramStory
        case instagramShareResponse(Result<Bool, Error>)
        
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.imageDownloadClient) var imageDownloadClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.archiveMediaClient) var archiveMediaClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
            case .onAppear:
                return .run { _ in await analyticsClient.logEvent(ArchiveAnalyticsEvent.photoDetailView) }
                
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case .toggleDropDownMenu:
                state.showDropDownMenu.toggle()
                return .none
                
            case .closeDropDownMenu:
                state.showDropDownMenu = false
                return .none
                
            case .toggleMemoVisibility:
                state.isMemoVisible.toggle()
                if !state.isMemoVisible { state.isMemoExpanded = false }
                return .none
                
            case let .toggleMemoExpanded(isExpanded):
                state.isMemoExpanded = isExpanded
                return .none
                
            case .startMemoEditing:
                state.isMemoEditing = true
                state.isMemoVisible = true
                state.isMemoExpanded = true
                state.editingMemoText = state.currentItem?.memo ?? ""
                return .none
                
            case .cancelMemoEditing:
                state.isMemoEditing = false
                state.isMemoExpanded = false
                return .none
                
            case .doneMemoEditing:
                let limitedText = String(state.editingMemoText.prefix(100))
                let photoID = state.currentItemID
                state.photos[id: photoID]?.memo = limitedText
                state.isMemoEditing = false
                state.isMemoExpanded = false
                
                return .run { send in
                    await send(.memoUpdateResponse(Result {
                        try await archiveClient.updatePhotoMemo(photoID: photoID, memo: limitedText)
                    }))
                }

            case .memoUpdateResponse(.success):
                return .run { _ in await analyticsClient.logEvent(ArchiveAnalyticsEvent.photoMemoCreate) }

            case .memoUpdateResponse(.failure):
                return .none
                
            case .clearAllMemoEditing:
                state.editingMemoText = ""
                return .none
                
            case .onTapTransform:
                state.showDropDownMenu = false
                guard let url = state.currentItem?.imageURL else { return .none }
                return .run { send in
                    do {
                        let imageData = try await archiveMediaClient.fetchOriginalImageData(url: url)
                        guard let image = UIImage(data: imageData) else { throw ArchivePhotoDetailError.imageDecodingFailed }
                        await send(.imageFetchResponse(.success(image)))
                    } catch {
                        await send(.imageFetchResponse(.failure(error)))
                    }
                }
                
            case let .imageFetchResponse(.success(image)):
                state.imageTransform = ImageTransformFeature.State(inputImage: image)
                return .none
                
            case .imageFetchResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("이미지를 불러오지 못했어요", style: .error))))
                
            case .onTapAddToAlbum:
                state.showDropDownMenu = false
                state.albumSelection = AlbumSelectionFeature.State(photoIDs: [state.currentItemID], selectionPurpose: .duplicate, currentAlbumId: state.folderId)
                return .none
                
            // 🌟 에러 수정 및 단일 상세 앨범 추가 GA4 로깅 적용 부분
            case let .albumSelection(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .didCompleteTask(message, albumCount): // 💡 누락되었던 albumCount 파라미터 추가!
                    state.albumSelection = nil
                    
                    return .merge(
                        .run { _ in
                            // 🌟 요구사항: 단일 정리 행동 분석 (album_add_from_detail)
                            await analyticsClient.logEvent(ArchiveAnalyticsEvent.albumAddFromDetail(albumCount: albumCount))
                        },
                        .send(.delegate(.showToast(NekiToastItem(message, style: .success))))
                    )
                    
                case .didTapCancel:
                    state.albumSelection = nil
                    return .none
                    
                case let .showToast(toastItem):
                    return .send(.delegate(.showToast(toastItem)))
                    
                case .didSelectForUpload:
                    return .none
                }
                
            case .onTapFavorite:
                guard let item = state.currentItem else { return .none }
                let newStatus = !item.isFavorite
                state.photos[id: item.id]?.isFavorite = newStatus
                return .run { [id = item.id, isFavorite = newStatus] send in
                    try? await archiveClient.toggleFavorite(photoID: id, request: isFavorite)
                }
                
            case .toggleFavoriteResponse:
                return .none
                
            case .onTapDownload:
                guard let url = state.currentItem?.imageURL else { return .none }
                state.isLoading = true
                return .run { [url = url] send in
                    let count = try await imageDownloadClient.downloadImages(urls: [url])
                    await send(.downloadImageResponse(successCount: count))
                }
                
            case let .downloadImageResponse(count):
                state.isLoading = false
                if count > 0 { return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success)))) }
                else { return .send(.delegate(.showToast(NekiToastItem("사진 저장에 실패했어요", style: .error)))) }
                
            case .onTapDelete:
                guard let id = state.currentItem?.id else { return .none }
                return .run { send in
                    try? await archiveClient.deletePhotoList(photoIds: [id])
                    await send(.deletePhotoResponse(.success(())))
                }
                
            case .deletePhotoResponse(.success):
                guard let deletedID = state.currentItem?.id else { return .none }
                
                let deletedIndex = state.photos.index(id: deletedID)
                state.photos.remove(id: deletedID)
                
                if state.photos.isEmpty {
                    return .run { send in
                        await send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                        await dismiss()
                    }
                }
                
                if let index = deletedIndex, index < state.photos.count {
                    state.currentItemID = state.photos[index].id
                } else if let last = state.photos.last {
                    state.currentItemID = last.id
                }
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
            case .deletePhotoResponse(.failure):
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제하지 못했어요", style: .error))))
                
            case .onTapShareToInstagramStory:
                state.showDropDownMenu = false
                guard let url = state.currentItem?.imageURL else { return .none }
                state.isLoading = true
                
                return .run { send in
                    await send(.instagramShareResponse(Result {
                        let imageData = try await archiveMediaClient.fetchOriginalImageData(url: url)
                        return try await archiveMediaClient.shareInstagramStory(imageData: imageData)
                    }))
                }
                
            case let .instagramShareResponse(.success(isShared)):
                state.isLoading = false
                guard isShared == false else { return .none }
                return .send(.delegate(.showToast(NekiToastItem("인스타그램 앱이 설치되어 있지 않아요", style: .error))))
                
            case .instagramShareResponse(.failure):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("이미지를 불러오지 못했어요", style: .error))))
                
            default:
                return .none
            }
        }
        .ifLet(\.$imageTransform, action: \.imageTransform) { ImageTransformFeature() }
        .ifLet(\.$albumSelection, action: \.albumSelection) { AlbumSelectionFeature() }
    }
}

private enum ArchivePhotoDetailError: Error {
    case imageDecodingFailed
}
