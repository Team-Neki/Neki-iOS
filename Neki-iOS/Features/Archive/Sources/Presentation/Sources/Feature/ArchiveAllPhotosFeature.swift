//
//  ArchiveAllPhotosFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/19/26.
//

import ComposableArchitecture
import Foundation
//import Core

@Reducer
struct ArchiveAllPhotosFeature {
    
    @ObservableState
    struct State {
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        var selectedIDs: Set<Int> = []
        
        var selectedSortedTime: String = "최신순" // "최신순" == DESC, "오래된순" == ASC
        var isSelectedFavorite: Bool = false
        var isSelectionMode: Bool = false
        
        // 페이징 관리
        var currentPage: Int = 0
        var hasNext: Bool = true
        var isFetchingPhotos: Bool = false
        
        // 선택된 사진이 있는지 여부
        var hasSelectedItems: Bool {
            return !selectedIDs.isEmpty
        }
        
        var filteredItems: IdentifiedArrayOf<ArchiveImageItem> {
            let filtered = isSelectedFavorite ? photos.filter { $0.isFavorite } : photos
            return IdentifiedArray(uniqueElements: filtered)
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // View Life Cycle Action
        case onAppear
        
        // User Action
        case onTapBackButton
        case onTapSelectButton
        case onTapCancelSelectButton
        case onTapDownloadButton
        
        // Delete Action
        case onTapDeleteButton
        case deletePhotosLocally(ids: [Int])
        
        // Filter Action
        case onTapFilterNewest
        case onTapFilterOldest
        case onTapFavoriteButton
        
        // Fetch Photo Action
        case fetchPhotos(isRefresh: Bool)
        case photoListResponse(Result<(photos: [PhotoEntity], hasNext: Bool), Error>)
        case loadMorePhotos
        
        case imageTapped(ArchiveImageItem)
        
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.archiveClient) var archiveClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
                // MARK: - View Life Cycle Action
                
            case .onAppear:
                if state.photos.isEmpty {
                    return .send(.fetchPhotos(isRefresh: true))
                }
                return .none
                
                
                // MARK: - User Action
                
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case .onTapSelectButton:
                state.isSelectionMode = true
                return .none
                
            case .onTapCancelSelectButton:
                state.isSelectionMode = false
                // 선택 모드 해제 시 모든 선택 상태 초기화
                state.selectedIDs.removeAll()
                return .none
                
            case .onTapDownloadButton:
                // TODO: - 다운로드 로직 구현
                let selectedItems = state.photos.filter { state.selectedIDs.contains($0.id) }
                print("다운로드할 항목: \(selectedItems.count)개")
                let toast = NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success)
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                return .send(.delegate(.showToast(toast)))
                
                
                // MARK: - Delete Action

            case .onTapDeleteButton:
                return .run { [selectedIDs = state.selectedIDs] send in
                    try await archiveClient.deletePhotoList(photoIds: Array(selectedIDs))

                    await send(.deletePhotosLocally(ids: Array(selectedIDs)))
                }

            case let .deletePhotosLocally(ids):
                state.$photos.withLock {
                    $0.removeAll { ids.contains($0.id) }
                }
                
                state.isSelectionMode = false
                state.selectedIDs.removeAll()
                
                return .send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                
                
                // MARK: - Filter Action
                
            case .onTapFilterNewest:
                if state.selectedSortedTime == "최신순" { return .none }
                state.selectedSortedTime = "최신순"
                return .send(.fetchPhotos(isRefresh: true))
                
            case .onTapFilterOldest:
                if state.selectedSortedTime == "오래된순" { return .none }
                state.selectedSortedTime = "오래된순"
                return .send(.fetchPhotos(isRefresh: true))
                
            case .onTapFavoriteButton:
                state.isSelectedFavorite.toggle()
                return .none
                
                
                // MARK: - Fetch Photo Action
                
            case let .fetchPhotos(isRefresh):
                if isRefresh {
                    state.currentPage = 0
                    state.hasNext = true
                }
                
                guard state.hasNext, !state.isFetchingPhotos else { return .none }
                state.isFetchingPhotos = true
                
                // "최신순" -> "DESC", "오래된순" -> "ASC" 변환
                let sortOrder = state.selectedSortedTime == "최신순" ? "DESC" : "ASC"
                
                return .run { [page = state.currentPage, sort = sortOrder] send in
                    await send(.photoListResponse(
                        Result {
                            try await archiveClient.fetchPhotoList(
                                folderId: nil,
                                page: page,
                                size: 20,
                                sortOrder: sort
                            )
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
                        isFavorite: entity.favorite,
                        date: isoFormatter.date(from: entity.createdAt) ?? Date(),
                        folderId: entity.folderId
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
                return .send(.delegate(.showToast(NekiToastItem("사진을 불러오지 못했어요", style: .error))))
                
            case .loadMorePhotos:
                return .send(.fetchPhotos(isRefresh: false))
                
            case let .imageTapped(item):
                if state.isSelectionMode {
                    if state.selectedIDs.contains(item.id) {
                        state.selectedIDs.remove(item.id)
                    } else {
                        state.selectedIDs.insert(item.id)
                    }
                } else {
                    // 상세 화면 이동 로직 (Coordinator에서 처리)
                }
                return .none
                
            default:
                return .none
            }
        }
    }
}
