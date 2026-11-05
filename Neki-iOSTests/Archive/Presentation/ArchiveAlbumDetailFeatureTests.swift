//
//  ArchiveAlbumDetailFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct ArchiveAlbumDetailFeatureTests {
    @Test("고른 사진을 다른 앨범으로 옮기면 사진 이동만 남긴다")
    func albumSelectionCompleted_withMove_logsPhotoMoveOnly() async {
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let store = makeStore(presenting: .move, events: events)

        await store.send(.albumSelection(.presented(.delegate(.didCompleteTask(
            message: "사진을 앨범으로 이동했어요",
            albumCount: 1,
            purpose: .move
        ))))).finish()

        #expect(events.value == [.photoMove])
    }

    @Test("고른 사진을 여러 앨범에 추가하면 여러 장 앨범 추가와 사진 복사를 함께 남긴다")
    func albumSelectionCompleted_withDuplicate_logsMultiAddAndPhotoCopy() async {
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let store = makeStore(presenting: .duplicate, events: events)

        await store.send(.albumSelection(.presented(.delegate(.didCompleteTask(
            message: "사진을 앨범에 추가했어요",
            albumCount: 2,
            purpose: .duplicate
        ))))).finish()

        #expect(events.value == [.albumAddFromMulti(photoCount: 2, albumCount: 2), .photoCopy])
    }

    @Test("다른 앨범의 사진을 가져오면 사진 가져오기와 사진 복사를 함께 남긴다")
    func photoImportCompleted_logsPhotoAddToAlbumAndPhotoCopy() async {
        var state = ArchiveAlbumDetailFeature.State(album: album)
        state.photoImport = PhotoImportFeature.State(targetAlbumId: album.id)
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events)

        await store.send(.photoImport(.presented(.delegate(.didCompleteTask(message: "사진을 가져왔어요", photoCount: 3))))).finish()

        #expect(events.value == [.photoAddToAlbum(photoCount: 3, albumCount: 1), .photoCopy])
    }
}


// MARK: - Helpers

private extension ArchiveAlbumDetailFeatureTests {
    var album: AlbumItem {
        AlbumItem(id: 10, title: "여행", count: 2, coverImageURL: nil, isFavorite: false)
    }

    /// 사진 두 장을 골라 앨범 선택 화면을 띄운 앨범 상세 스토어입니다.
    func makeStore(
        presenting purpose: PhotoSelectionPurpose,
        events: LockIsolated<[ArchiveAnalyticsEvent]>
    ) -> StoreOf<ArchiveAlbumDetailFeature> {
        var state = ArchiveAlbumDetailFeature.State(album: album)
        state.isSelectionMode = true
        state.selectedIDs = [1, 2]
        state.albumSelection = AlbumSelectionFeature.State(photoIDs: [1, 2], selectionPurpose: purpose, currentAlbumId: album.id)
        return makeStore(initialState: state, events: events)
    }

    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다.
    ///
    /// `ArchiveAlbumDetailFeature.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    /// 작업을 마치면 사진을 다시 불러오므로, 사진 조회는 실패로 바로 끝냅니다.
    func makeStore(
        initialState: ArchiveAlbumDetailFeature.State,
        events: LockIsolated<[ArchiveAnalyticsEvent]>
    ) -> StoreOf<ArchiveAlbumDetailFeature> {
        Store(initialState: initialState) {
            ArchiveAlbumDetailFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? ArchiveAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            $0.archiveClient.refreshPhotos = { _, _, _ in throw ArchiveFailure() }
        }
    }
}

private struct ArchiveFailure: Error {}
