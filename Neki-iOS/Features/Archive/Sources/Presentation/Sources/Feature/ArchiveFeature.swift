//
//  ArchiveFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import os
import AVFoundation
//import Core

@Reducer
struct ArchiveFeature {
    
    @ObservableState
    struct State {
        @Shared(.inMemory("archive-photos")) var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        @Shared(.inMemory("archive-albums")) var albums: IdentifiedArrayOf<AlbumItem> = []
        
        @Presents var selectUploadAlbum: SelectUploadAlbumFeature.State?
        @Presents var qrScanner: QRCodeScanFeature.State?
        
        var newAlbumTitle: String = ""
        
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
        
        var showDropDownMenu: Bool = false
        
        var imagePicker = ImagePickerFeature.State(
            maxCount: 10,
            mediaType: .photoBooth // 테스트를 위한 temp, .photoBooth로 변경 예정
        )
        var isLoading: Bool = false // 업로드 시 로딩
        
        var currentPage: Int = 0
        var hasNext: Bool = true
        var isFetchingPhotos: Bool = false // 사진 fetch시 로딩
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // View Life Cycle Action
        case onAppear
        
        // User Action
        case toggleDropDownMenu
        case closeDropDownMenu
        case onTapAllPhotos
        case onTapAllAlbums
        case onTapQRScan
        
        // Add Folder Action
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        case addFolderResponse(Result<Int, Error>)
        
        // Fetch Album(Folder) Action
        case fetchAlbums
        case favoriteAlbumResponse(Result<AlbumItem, Error>)      // 즐겨찾기
        case normalAlbumsResponse(Result<[AlbumItem], Error>)
        
        // Image Upload Action
        case imagePicker(ImagePickerFeature.Action)
        case selectUploadAlbum(PresentationAction<SelectUploadAlbumFeature.Action>)
        
        // Fetch Photo Action
        case fetchPhotos(isRefresh: Bool)
        case photoListResponse(Result<(photos: [PhotoEntity], hasNext: Bool), Error>)
        case loadMorePhotos
        
        // Navigation Action
        case imageTapped(ArchiveImageItem)
        case albumTapped(AlbumItem)
        case afterUploadNavigateToAlbumDetail(AlbumItem)
        case qrScannerPresented
        
        // Internal Action
        case showPermissionAlert
        
        // Delegate Action
        case delegate(DelegateAction)
        enum DelegateAction {
            case showToast(NekiToastItem)
        }
        
        // Child Action
        case qrScanner(PresentationAction<QRCodeScanFeature.Action>)
    }
    
    @Dependency(\.archiveClient) var archiveClient
    @Dependency(\.qrScannerClient) private var qrScannerClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) {
            ImagePickerFeature()
        }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            /// 화면전환과 관련된 액션은 default를 이용해 무시하고 나머지 case만 사용
            switch action {
                
                // MARK: - View Life Cycle Action
                
            case .onAppear:
                return .merge(
                    state.albums.isEmpty ? .send(.fetchAlbums) : .none,
                    state.photos.isEmpty ? .send(.fetchPhotos(isRefresh: true)) : .none
                )
                
                // MARK: - User Action
                
            case .toggleDropDownMenu:
                state.showDropDownMenu.toggle()
                return .none
                
            case .closeDropDownMenu:
                state.showDropDownMenu = false
                return .none
                
            case .onTapQRScan:
                defer { state.showDropDownMenu = false }
                switch qrScannerClient.checkAuthorizationStatus() {
                case .authorized:
                    return .send(.qrScannerPresented)
                    
                case .notDetermined:
                    return .run { send in
                        let isAuthorized = await qrScannerClient.requestAccess()
                        guard isAuthorized else { return await send(.showPermissionAlert) }
                        await send(.qrScannerPresented)
                    }
                    
                case .denied, .restricted:
                    return .send(.showPermissionAlert)
                    
                @unknown default:
                    return .none
                }
                
                
                // MARK: - Add Folder Action
                
            case .onTapCancelAddAlbum:
                state.showDropDownMenu = false
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                return .none
                
            case .onTapConfirmAddAlbum:
                guard state.isConfirmButtonEnabled else { return .none }
                
                let title = state.newAlbumTitle.trimmingCharacters(in: .whitespaces)
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                
                return .run { send in
                    await send(.addFolderResponse(Result {
                        try await archiveClient.addFolder(name: title)
                    }))
                }
                
            case .addFolderResponse(.success):
                let toastItem = NekiToastItem("새로운 앨범을 추가했어요", style: .success)
                
                return .run { send in
                    await send(.delegate(.showToast(toastItem)))
                    await send(.fetchAlbums)
                }
                
            case .addFolderResponse(.failure):
                let toastItem = NekiToastItem("앨범을 만들지 못했어요", style: .error)
                return .send(.delegate(.showToast(toastItem)))
                
                
                // MARK: - Image Upload Action
                
            case .qrScannerPresented:
                state.qrScanner = QRCodeScanFeature.State()
                return .none
                
            case .imagePicker(.uploadStarted):
                state.isLoading = true
                state.showDropDownMenu = false
                return .none
                
            case let .imagePicker(.uploadCompleted(ids)):
                state.isLoading = false
                if ids.isEmpty { return .none }
                
                state.selectUploadAlbum = SelectUploadAlbumFeature.State(
                    uploadedImageIds: ids,
                    albums: state.albums
                )
                return .none
                
            case let .selectUploadAlbum(.presented(.delegate(delegateAction))):
                switch delegateAction {
                case let .uploadDidSuccess(albumId):
                    state.selectUploadAlbum = nil // 팝업 닫기
                    let toast = NekiToastItem("이미지를 추가했어요", style: .success)
                    
                    // 앨범 선택했다면 해당 앨범으로 이동 요청
                    if let albumId = albumId,
                       let album = state.albums.first(where: { $0.id == albumId }) {
                        return .run { send in
                            await send(.delegate(.showToast(toast)))
                            await send(.fetchPhotos(isRefresh: true))
                            await send(.fetchAlbums)
                            
                            /// fullScreenCover가 내려가고 전환해야 사진이 잘 불러와짐
                            /// fullScreenCover가 내려가는 0.35초보다 빨리 전환 시 사진이 fetch가 안 돼서 빈 화면만 보임
                            try? await Task.sleep(for: .milliseconds(400))
                            
                            await send(.afterUploadNavigateToAlbumDetail(album))
                        }
                    }
                    
                    return .run { send in
                        await send(.delegate(.showToast(toast)))
                        await send(.fetchAlbums)
                        await send(.fetchPhotos(isRefresh: true))
                    }
                    
                case .uploadDidFail:
                    state.selectUploadAlbum = nil // 팝업 닫기
                    let toast = NekiToastItem("업로드에 실패했어요", style: .error)
                    return .send(.delegate(.showToast(toast)))
                    
                }
                
            case .imagePicker(.uploadFailed):
                state.isLoading = false
                let toast = NekiToastItem("업로드에 실패했어요", style: .error)
                return .send(.delegate(.showToast(toast)))
                
                
                // MARK: - Fetch Album Action
                
            case .fetchAlbums:
                return .merge(
                    .run { send in
                        do {
                            let entity = try await archiveClient.getFavoriteAlbumInfo()
                            
                            let favoriteAlbum = AlbumItem(
                                id: 0,
                                title: "즐겨찾기",
                                count: entity.totalCount,
                                // TODO: - 없을 시 브랜딩 이미지로 변경
                                coverImageURL: URL(string: entity.latestImageURL.isEmpty ? "" : entity.latestImageURL),
                                isFavorite: true
                            )
                            
                            await send(.favoriteAlbumResponse(.success(favoriteAlbum)))
                            
                        } catch {
                            await send(.favoriteAlbumResponse(.failure(error)))
                        }
                    },
                    .run { send in
                        do {
                            let entities = try await archiveClient.getAlbumList()
                            
                            let folders: [AlbumItem] = entities.map {
                                AlbumItem(
                                    id: $0.id,
                                    title: $0.name,
                                    count: $0.photoCount,
                                    coverImageURL: URL(string: $0.coverImageURLString), // TODO: - 없으면 브랜딩 이미지
                                    isFavorite: false
                                )
                            }
                            
                            await send(.normalAlbumsResponse(.success(folders)))
                            
                        } catch {
                            await send(.normalAlbumsResponse(.failure(error)))
                        }
                    }
                )
                
            case let .favoriteAlbumResponse(.success(result)):
                state.$albums.withLock { existing in
                    existing.removeAll(where: { $0.isFavorite })
                    existing.insert(result, at: 0)
                }
                return .none
                
            case .favoriteAlbumResponse(.failure):
                let toast = NekiToastItem("즐겨찾기 앨범을 불러오지 못했어요", style: .error)
                return .send(.delegate(.showToast(toast)))
                
            case let .normalAlbumsResponse(.success(result)):
                state.$albums.withLock { existing in
                    var favoriteAlbum: AlbumItem?
                    if let first = existing.first, first.isFavorite {
                        favoriteAlbum = first
                    }
                    
                    var newAlbums: [AlbumItem] = []
                    if let fav = favoriteAlbum {
                        newAlbums.append(fav)
                    }
                    newAlbums.append(contentsOf: result)
                    
                    existing = IdentifiedArray(uniqueElements: newAlbums)
                }
                return .none
                
                
            case .normalAlbumsResponse(.failure):
                let toast = NekiToastItem("앨범을 불러오지 못했어요", style: .error)
                return .send(.delegate(.showToast(toast)))
                
                
                // MARK: - Fetch Photo Action
                
            case let .fetchPhotos(isRefresh):
                if isRefresh {
                    state.currentPage = 0
                    state.hasNext = true
                }
                
                guard state.hasNext,
                      !state.isFetchingPhotos else { return .none }
                
                state.isFetchingPhotos = true
                
                return .run { [page = state.currentPage] send in
                    await send(.photoListResponse(
                        Result {
                            try await archiveClient.fetchPhotoList(folderId: nil, page: page, size: 20, sortOrder: nil)
                        }
                    ))
                }
                
            case let .photoListResponse(.success(result)):
                state.isFetchingPhotos = false
                state.hasNext = result.hasNext
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let newItems = result.photos.map { entity in
                    ArchiveImageItem(
                        id: entity.photoID,
                        imageURLString: entity.imageURL,
                        isFavorite: entity.isfavorite,
                        date: isoFormatter.date(from: entity.createdAt) ?? Date()
                    )
                }
                
                if state.currentPage == 0 {
                    state.$photos.withLock { $0 = IdentifiedArray(uniqueElements: newItems) }
                } else {
                    state.$photos.withLock { $0.append(contentsOf: newItems) }
                }
                
                state.currentPage += 1
                return .none
                
            case .photoListResponse(.failure):
                state.isFetchingPhotos = false
                let toast = NekiToastItem("사진을 불러오지 못했어요", style: .error)
                return .send(.delegate(.showToast(toast)))
                
            case .loadMorePhotos:
                return .send(.fetchPhotos(isRefresh: false))
                
                
                // MARK: - Binding Action
                
            case .binding(\.newAlbumTitle):
                let inputTitle = state.newAlbumTitle.trimmingCharacters(in: .whitespaces)
                
                if state.albums.contains(where: { $0.title == inputTitle }) {
                    state.albumTitleErrorMessage = "이미 사용 중인 앨범명이에요."
                } else {
                    state.albumTitleErrorMessage = nil
                }
                return .none
                
            case let .qrScanner(.presented(.imageProcessingResult(processedID))):
                state.qrScanner = nil
                // TODO: QR 파싱 후 업로드 끝난 ID를 어떻게 해야하는거지?
                let toast = NekiToastItem("이미지를 추가했어요", style: .success)
                return .send(.delegate(.showToast(toast)))
                
            default:
                return .none
            }
        }
        .ifLet(\.$selectUploadAlbum, action: \.selectUploadAlbum) {
            SelectUploadAlbumFeature()
        }
        .ifLet(\.$qrScanner, action: \.qrScanner) {
            QRCodeScanFeature()
        }
    }
}

