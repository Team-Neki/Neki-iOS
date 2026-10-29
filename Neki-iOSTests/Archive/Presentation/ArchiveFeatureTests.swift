//
//  ArchiveFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct ArchiveFeatureTests {
    @Test("아카이브 첫 화면이 보일 때마다 화면 진입을 남긴다")
    func onAppear_logsArchivingViewEveryTime() async {
        let events = LockIsolated<[ArchiveAnalyticsEvent]>([])
        let store = Store(initialState: ArchiveFeature.State()) {
            ArchiveFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? ArchiveAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
            // 화면이 보이면 앨범과 사진을 불러오므로, 조회는 실패로 바로 끝냅니다.
            $0.archiveClient.getFavoriteAlbumInfo = { throw ArchiveFailure() }
            $0.archiveClient.getAlbumList = { throw ArchiveFailure() }
            $0.archiveClient.refreshPhotos = { _, _, _ in throw ArchiveFailure() }
        }

        await store.send(.onAppear).finish()
        await store.send(.onAppear).finish()

        #expect(events.value == [.archivingView, .archivingView])
    }
}

private struct ArchiveFailure: Error {}
