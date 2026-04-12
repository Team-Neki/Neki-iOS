//
//  ArchivePhotoDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

@Reducer
struct ArchivePhotoDetailFeature {
    @ObservableState
    struct State {
        @Presents var imageTransform: ImageTransformFeature.State?
        @Presents var albumSelection: AlbumSelectionFeature.State?
        
        var photos: IdentifiedArrayOf<ArchiveImageItem>
        var currentItemID: Int
        let folderId: Int?
        
        var currentItem: ArchiveImageItem? { photos[id: currentItemID] }
        var formattedDate: String {
            return currentItem?.date.toDotFormatString() ?? ""
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
        
        case toggleMemoVisibility
        case toggleMemoExpanded(Bool)
        case startMemoEditing
        case cancelMemoEditing
        case doneMemoEditing
        case clearAllMemoEditing
        
        case onTapTransform
        case imageFetchResponse(Result<UIImage, Error>)
        case imageTransform(PresentationAction<ImageTransformFeature.Action>)
        
        case onTapAddToAlbum
        case albumSelection(PresentationAction<AlbumSelectionFeature.Action>)
        case addToAlbumResponse(Result<Void, Error>)
        
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
        case instagramImageFetchResponse(Result<UIImage, Error>)
        
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
        
        Reduce { state, action in
            switch action {
                
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
                // MARK: - DropDown Menu
            case .toggleDropDownMenu:
                state.showDropDownMenu.toggle()
                return .none
                
            case .closeDropDownMenu:
                state.showDropDownMenu = false
                return .none
                
                // MARK: - Memo
            case .toggleMemoVisibility:
                state.isMemoVisible.toggle()
                if !state.isMemoVisible {
                    state.isMemoExpanded = false
                }
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
                    try? await archiveClient.updatePhotoMemo(photoID: photoID, memo: limitedText)
                }
                
            case .clearAllMemoEditing:
                state.editingMemoText = ""
                return .none
                
                // MARK: - Image Transform
            case .onTapTransform:
                state.showDropDownMenu = false
                
                guard let url = state.currentItem?.imageURL else { return .none }
                
                return .run { send in
                    do {
                        let image = try await withCheckedThrowingContinuation { continuation in
                            KingfisherManager.shared.retrieveImage(
                                with: url,
                                options: [.cacheOriginalImage]
                            ) { result in
                                switch result {
                                case .success(let value):
                                    continuation.resume(returning: value.image)
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
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
                
                
                // MARK: - Add To Album
            case .onTapAddToAlbum:
                state.showDropDownMenu = false
                state.albumSelection = AlbumSelectionFeature.State(uploadCount: 1, selectionPurpose: .duplicate, currentAlbumId: state.folderId)
                return .none
                
            case let .albumSelection(.presented(.delegate(delegateAction))):
                switch delegateAction {
                    
                case .didSelectAlbums:
                    state.albumSelection = nil
                    state.isLoading = true
                    
                    // TODO: - 실제 API 연결하기
                    return .run { send in
                        try? await Task.sleep(for: .seconds(1))
                        await send(.addToAlbumResponse(.success(())))
                    }
                    
                case .didTapCancel:
                    state.albumSelection = nil
                    return .none
                    
                case let .showToast(toastItem):
                    return .send(.delegate(.showToast(toastItem)))
                }
                
            case .addToAlbumResponse(.success):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("사진을 앨범에 추가했어요", style: .success))))
                
            case .addToAlbumResponse(.failure):
                state.isLoading = false
                return .send(.delegate(.showToast(NekiToastItem("앨범 추가에 실패했어요", style: .error))))
                
                
                // MARK: - 즐겨찾기
            case .onTapFavorite:
                guard let item = state.currentItem else { return .none }
                let newStatus = !item.isFavorite
                state.photos[id: item.id]?.isFavorite = newStatus
                
                return .run { [id = item.id, isFavorite = newStatus] send in
                    try? await archiveClient.toggleFavorite(photoID: id, request: isFavorite)
                }
                
            case .toggleFavoriteResponse:
                return .none
                
                
                // MARK: - 다운로드
            case .onTapDownload:
                guard let url = state.currentItem?.imageURL else { return .none }
                state.isLoading = true
                
                return .run { [url = url] send in
                    let count = try await imageDownloadClient.downloadImages(urls: [url])
                    await send(.downloadImageResponse(successCount: count))
                }
                
            case let .downloadImageResponse(count):
                state.isLoading = false
                
                if count > 0 {
                    return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success))))
                } else {
                    return .send(.delegate(.showToast(NekiToastItem("사진 저장에 실패했어요", style: .error))))
                }
                
                
                // MARK: - 삭제
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
                    do {
                        let image = try await withCheckedThrowingContinuation { continuation in
                            KingfisherManager.shared.retrieveImage(
                                with: url,
                                options: [.cacheOriginalImage]
                            ) { result in
                                switch result {
                                case .success(let value):
                                    continuation.resume(returning: value.image)
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                        await send(.instagramImageFetchResponse(.success(image)))
                    } catch {
                        await send(.instagramImageFetchResponse(.failure(error)))
                    }
                }
                
            case let .instagramImageFetchResponse(.success(image)):
                state.isLoading = false
                return .run { send in
                    // 이미지를 클립보드에 담고 인스타그램 앱 열기 (MainActor에서 실행)
                    let isShared = await MainActor.run { () -> Bool in
                        guard let urlScheme = URL(string: "instagram-stories://share?source_application=Neki") else { return false }
                        
                        // 인스타그램 앱이 설치되어 있는지 확인
                        if UIApplication.shared.canOpenURL(urlScheme) {
                            if let imageData = image.pngData() {
                                // 인스타 스토리 배경으로 이미지 전달
                                let pasteboardItems: [[String: Any]] = [
                                    ["com.instagram.sharedSticker.backgroundImage": imageData]
                                ]
                                let pasteboardOptions = [
                                    UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(60 * 5)
                                ]
                                
                                UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
                                UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
                                return true
                            }
                        }
                        return false
                    }
                    
                    // 설치되어 있지 않거나 실패한 경우 토스트
                    if !isShared {
                        await send(.delegate(.showToast(NekiToastItem("인스타그램 앱이 설치되어 있지 않아요", style: .error))))
                    }
                }
                
            case .instagramImageFetchResponse(.failure):
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
