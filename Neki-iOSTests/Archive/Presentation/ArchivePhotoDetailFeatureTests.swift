//
//  ArchivePhotoDetailFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct ArchivePhotoDetailFeatureTests {
    @Test("메모를 바꾸지 않고 편집을 마치면 저장을 요청하지 않고 메모 작성도 남기지 않는다")
    func doneMemoEditing_withSameMemo_doesNotSaveOrLog() async {
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let savedMemos = LockIsolated<[String]>([])
        let store = makeStore(memo: "첫 메모", events: events, savedMemos: savedMemos)
        store.send(.startMemoEditing)

        await store.send(.doneMemoEditing).finish()

        #expect(savedMemos.value.isEmpty)
        #expect(events.value.isEmpty)
        #expect(store.isMemoEditing == false)
    }

    @Test("메모를 바꿔 편집을 마치면 저장을 요청하고, 저장에 성공하면 메모 작성을 남긴다")
    func doneMemoEditing_withChangedMemo_savesAndLogs() async {
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let savedMemos = LockIsolated<[String]>([])
        let store = makeStore(memo: "첫 메모", events: events, savedMemos: savedMemos)
        store.send(.startMemoEditing)
        store.send(.binding(.set(\.editingMemoText, "바꾼 메모")))

        await store.send(.doneMemoEditing).finish()

        #expect(savedMemos.value == ["바꾼 메모"])
        #expect(events.value == [.photoMemoCreate])
        #expect(store.currentItem?.memo == "바꾼 메모")
    }
}


// MARK: - Helpers

private extension ArchivePhotoDetailFeatureTests {
    /// 메모가 적힌 사진 한 장을 보고 있는 사진 상세 스토어입니다.
    ///
    /// `ArchivePhotoDetailFeature.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    /// 보낸 분석 이벤트는 `events`에, 저장을 요청한 메모는 `savedMemos`에 차례로 모읍니다.
    func makeStore(
        memo: String,
        events: LockIsolated<[ArchiveAnalyticsEvent]>,
        savedMemos: LockIsolated<[String]>
    ) -> StoreOf<ArchivePhotoDetailFeature> {
        Store(initialState: ArchivePhotoDetailFeature.State(
            photos: [PhotoEntity(id: 1, imageURL: nil, memo: memo)],
            currentItemID: 1,
            folderId: nil
        )) {
            ArchivePhotoDetailFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? ArchiveAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            $0.archiveClient.updatePhotoMemo = { _, memo in
                savedMemos.withValue { $0.append(memo) }
            }
        }
    }
}
