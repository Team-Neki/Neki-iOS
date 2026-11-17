//
//  OffsetBookmarkServer.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/17/26.
//

import ComposableArchitecture
@testable import Neki_iOS

/// 서버처럼 북마크 목록을 자리로 잘라 주는 흉내 서버입니다.
///
/// 해제하면 뒤 포즈가 앞으로 당겨지고, 새 북마크는 맨 앞에 들어갑니다.
struct OffsetBookmarkServer: Sendable {
    let ids: LockIsolated<[PoseID]>

    init(ids: [PoseID]) {
        self.ids = LockIsolated(ids)
    }

    func page(_ page: Int, size: Int) -> PoseListPage {
        let ids = ids.value
        let start = min(page * size, ids.count)
        let end = min(start + size, ids.count)
        let poses = ids[start..<end].map {
            Pose(id: $0, peopleCountOption: .solo, imageURL: nil, isScrapped: true, contentType: .jpeg, width: nil, height: nil)
        }
        return PoseListPage(poses: poses, hasNext: end < ids.count, totalCount: ids.count)
    }

    func toggle(_ id: PoseID) {
        ids.withValue { ids in
            if let index = ids.firstIndex(of: id) {
                ids.remove(at: index)
            } else {
                ids.insert(id, at: .zero)
            }
        }
    }
}
