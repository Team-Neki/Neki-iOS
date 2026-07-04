//
//  ArchiveAllPhotosFeatureTests.swift
//  Neki-iOSTests
//
//  Created by Codex on 7/3/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct ArchiveAllPhotosFeatureTests {
    @Test("첫 조회 응답의 페이지 상태와 Masonry column을 반영한다")
    func fetchPhotos_appliesSnapshot() async {
        let photos = [makePhoto(id: 1), makePhoto(id: 2), makePhoto(id: 3)]
        let snapshot = ArchivePhotoSnapshot(photos: photos, totalCount: 3, hasNext: false)
        var state = ArchiveAllPhotosFeature.State()
        state.isFetchingPhotos = true
        let store = makeStore(initialState: state)

        await store.send(.photoListResponse(.success(snapshot))) {
            $0.isFetchingPhotos = false
            $0.hasNextPhotos = false
            $0.photos = IdentifiedArray(uniqueElements: photos)
            $0.photoColumns = ArchiveMasonryLayout.columns(for: photos)
            $0.lastVisiblePhotoID = 3
        }
    }

    @Test("마지막 페이지 이후 추가 요청을 보내지 않는다")
    func loadMorePhotos_whenHasNoNextPage_doesNothing() async {
        var state = ArchiveAllPhotosFeature.State()
        state.hasNextPhotos = false
        let store = makeStore(initialState: state)

        await store.send(.loadMorePhotos)
    }

    @Test("즐겨찾기 필터는 즐겨찾기 사진 ID만 column에 유지한다")
    func favoriteFilter_updatesVisibleColumns() async {
        let photos = [
            makePhoto(id: 1, isFavorite: true),
            makePhoto(id: 2, isFavorite: false),
            makePhoto(id: 3, isFavorite: true)
        ]
        var state = ArchiveAllPhotosFeature.State()
        state.photos = IdentifiedArray(uniqueElements: photos)
        state.photoColumns = ArchiveMasonryLayout.columns(for: photos)
        let store = makeStore(initialState: state)

        await store.send(.onTapFavoriteButton) {
            $0.isSelectedFavorite = true
            $0.photoColumns = ArchiveMasonryLayout.columns(for: [photos[0], photos[2]])
            $0.lastVisiblePhotoID = 3
        }
    }
}

private extension ArchiveAllPhotosFeatureTests {
    func makeStore(
        initialState: ArchiveAllPhotosFeature.State = .init(),
        snapshot: ArchivePhotoSnapshot = .init(photos: [], totalCount: 0, hasNext: false)
    ) -> TestStoreOf<ArchiveAllPhotosFeature> {
        let store = TestStore(initialState: initialState) {
            ArchiveAllPhotosFeature()
        } withDependencies: {
            $0.archiveClient.refreshPhotos = { _, _, _ in snapshot }
            $0.archiveClient.fetchNextPhotos = { _, _, _ in snapshot }
        }
        store.exhaustivity = .off
        return store
    }

    func makePhoto(id: Int, isFavorite: Bool = false) -> PhotoEntity {
        PhotoEntity(
            id: id,
            imageURL: URL(string: "https://example.com/\(id).jpg"),
            isFavorite: isFavorite,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }
}
