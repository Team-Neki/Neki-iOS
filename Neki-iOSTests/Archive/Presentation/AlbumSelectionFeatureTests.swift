//
//  AlbumSelectionFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct AlbumSelectionFeatureTests {
    @Test("앨범 선택 화면에서 새 앨범을 만들면 앨범 생성을 남긴다")
    func addFolderResponse_success_logsAlbumCreate() async {
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let store = makeStore(events: events)

        await store.send(.addFolderResponse(.success(7)))
        await store.finish()

        #expect(events.value == [.albumCreate])
    }

    @Test("앨범을 만들지 못하면 앨범 생성을 남기지 않는다")
    func addFolderResponse_failure_doesNotLogAlbumCreate() async {
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let store = makeStore(events: events)

        await store.send(.addFolderResponse(.failure(ArchiveFailure())))
        await store.finish()

        #expect(events.value.isEmpty)
    }

    @Test("사진을 옮기거나 복사하고 나면 받는 화면이 맞는 이벤트를 보내도록 어떤 작업이었는지 함께 알린다", arguments: [true, false])
    func tapConfirm_completesTaskWithPurpose(isMove: Bool) async {
        let purpose: PhotoSelectionPurpose = isMove ? .move : .duplicate
        let store = makeStore(initialState: AlbumSelectionFeature.State(photoIDs: [1, 2], selectionPurpose: purpose, currentAlbumId: 10))

        await store.send(.tapAlbum(20))
        await store.send(.tapConfirm)

        await store.receive({ action in
            guard case let .delegate(.didCompleteTask(_, albumCount, completedPurpose)) = action else { return false }
            return albumCount == 1 && completedPurpose == purpose
        })
    }
}


// MARK: - Helpers

private extension AlbumSelectionFeatureTests {
    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다. 이펙트가 보내는 액션은 확인하지 않습니다.
    ///
    /// 앨범을 만들면 앨범 목록을 다시 불러오므로, 목록 조회는 실패로 바로 끝냅니다.
    func makeStore(
        initialState: AlbumSelectionFeature.State = .init(selectionPurpose: .duplicate),
        events: LockIsolated<[ArchiveAnalyticsEvent]> = .init([])
    ) -> TestStoreOf<AlbumSelectionFeature> {
        let store = TestStore(initialState: initialState) {
            AlbumSelectionFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? ArchiveAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            $0.archiveClient.getFavoriteAlbumInfo = { throw ArchiveFailure() }
            $0.archiveClient.getAlbumList = { throw ArchiveFailure() }
            $0.archiveClient.duplicatePhoto = { _, _ in }
            $0.archiveClient.movePhoto = { _, _, _ in }
        }
        store.exhaustivity = .off
        return store
    }
}

private struct ArchiveFailure: Error {}
