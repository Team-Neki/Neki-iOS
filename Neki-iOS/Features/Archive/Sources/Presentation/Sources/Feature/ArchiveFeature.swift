//
//  ArchiveFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
//import Core

@Reducer
struct ArchiveFeature {
    
    @ObservableState
    struct State {
        @Shared(.inMemory("archive-photos")) var photos: IdentifiedArrayOf<ArchiveImageItem> = []
        @Shared(.inMemory("archive-albums")) var albums: IdentifiedArrayOf<AlbumItem> = []
        
        @Presents var selectUploadAlbum: SelectUploadAlbumFeature.State?
        
        var newAlbumTitle: String = ""
        
        var albumTitleErrorMessage: String? = nil
        
        var isConfirmButtonEnabled: Bool {
            return !newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumTitleErrorMessage == nil
        }
        
        var showDropDownMenu: Bool = false
        
        var imagePicker = ImagePickerFeature.State(
            maxCount: 10,
            mediaType: .temp // 테스트를 위한 temp, .photoBooth로 변경 예정
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
        case onTapCancelAddAlbum
        case onTapConfirmAddAlbum
        
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
        
        // Delegate Action
        case delegate(DelegateAction)
        enum DelegateAction {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.archiveClient) var archiveClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.imagePicker, action: \.imagePicker) {
            ImagePickerFeature()
        }
        
        Reduce { state, action in
            /// 화면전환과 관련된 액션은 default를 이용해 무시하고 나머지 case만 사용
            switch action {
                
                // MARK: - View Life Cycle Action
                
            case .onAppear:
                if state.albums.isEmpty {
                    let loadedAlbums = IdentifiedArray(uniqueElements: AlbumItem.dummyData())
                    state.$albums.withLock { $0 = loadedAlbums }
                }
                
                return .send(.fetchPhotos(isRefresh: true))
                
                
                // MARK: - User Action
                
            case .toggleDropDownMenu:
                state.showDropDownMenu.toggle()
                return .none
                
            case .closeDropDownMenu:
                state.showDropDownMenu = false
                return .none
                
            case .onTapQRScan:
                print("QR 인식")
                state.showDropDownMenu = false
                return .none
                
            case .onTapCancelAddAlbum:
                state.showDropDownMenu = false
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                return .none
                
            case .onTapConfirmAddAlbum:
                guard state.isConfirmButtonEnabled else { return .none }
                
                let newAlbum = AlbumItem(
                    id: Int.random(in: -9999...(-1)),
                    title: state.newAlbumTitle,
                    count: 0,
                    coverImageURL: nil,         // TODO: - 디자인에서 주는 브랜딩 이미지로 변경
                    isFavorite: false
                )
                
                state.$albums.withLock {
                    _ = $0.insert(newAlbum, at: 1)
                }
                
                // 입력값 초기화
                state.newAlbumTitle = ""
                state.albumTitleErrorMessage = nil
                
                let toastItem = NekiToastItem(
                    "새로운 앨범을 추가했어요",
                    style: .success
                )
                
                return .send(.delegate(.showToast(toastItem)))
                
                
                // MARK: - Image Upload Action
                
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
                            await send(.afterUploadNavigateToAlbumDetail(album))
                            await send(.fetchPhotos(isRefresh: true))
                        }
                    }
                    
                    return .send(.delegate(.showToast(toast)))
                }
                
            case .imagePicker(.uploadFailed):
                state.isLoading = false
                let toast = NekiToastItem("업로드에 실패했어요", style: .error)
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
                        id: entity.photoId,
                        imageURLString: entity.imageUrl,
                        isScrapped: entity.favorite,
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
                
            case let .photoListResponse(.failure(error)):
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
                
                
            default:
                return .none
            }
        }
        .ifLet(\.$selectUploadAlbum, action: \.selectUploadAlbum) {
            SelectUploadAlbumFeature()
        }
    }
}

