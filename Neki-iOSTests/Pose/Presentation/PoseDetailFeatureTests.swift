//
//  PoseDetailFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/17/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct PoseDetailFeatureTests {
    @Test("그리드 목록을 이어 넘기는 상세는 지금 포즈 뒤에 남은 포즈가 미리 받을 수 이하일 때만 다음 페이지가 필요하다")
    func needsMorePoses_onlyWhenRemainingWithinPrefetchCount() {
        let prefetchCount = PoseDetailFeature.State.paginationPrefetchCount
        var state = PoseDetailFeature.State(poses: makePoses(1...20), selectedID: 1, followsList: true)

        #expect(state.needsMorePoses == false)

        state.selectedID = 20 - prefetchCount - 1
        #expect(state.needsMorePoses == false)

        state.selectedID = 20 - prefetchCount
        #expect(state.needsMorePoses)

        state.selectedID = 20
        #expect(state.needsMorePoses)
    }

    @Test("랜덤 포즈에서 연 상세는 끝에 있어도 다음 페이지가 필요하지 않다")
    func needsMorePoses_randomPoseDetail_isFalse() {
        let state = PoseDetailFeature.State(poses: makePoses(1...20), selectedPose: makePose(id: 500), followsList: false)

        #expect(state.poses.last?.id == 500)
        #expect(state.needsMorePoses == false)
    }

    @Test("끝 가까이에서 연 상세가 나타나면 자기 포즈 정보만 받고 다음 페이지는 요청하지 않는다")
    func onAppear_nearEnd_fetchesOnlyPoseDetail() async {
        let state = PoseDetailFeature.State(poses: makePoses(1...20), selectedID: 20, followsList: true)
        #expect(state.needsMorePoses)
        let fetchedPose = Pose(id: 20, peopleCountOption: .solo, imageURL: nil, isScrapped: false, contentType: .jpeg, width: 300, height: 400)
        let store = TestStore(initialState: state) {
            PoseDetailFeature()
        } withDependencies: {
            $0.poseClient.fetchPoseDetail = { _ in fetchedPose }
        }

        // 다음 페이지는 상세를 여는 코디네이터가 요청합니다. 상세가 나타날 때 요청하면 화면의 `.task`에 묶여, 응답 전에 뒤로 가면 요청이 취소됩니다.
        await store.send(.onAppear)
        await store.receive { action in
            guard case .poseDetailResponse(_, .success) = action else { return false }
            return true
        } assert: {
            $0.poses[id: 20] = fetchedPose
        }
        await store.receive { action in
            guard case .delegate(.poseFetched) = action else { return false }
            return true
        }
    }

    @Test("그리드 목록이 받은 포즈 중 상세에 없는 포즈만 끝에 붙이고, 그리드 목록에서 빠진 포즈는 상세의 제자리에 둔다")
    func appendPoses_appendsOnlyMissingPosesInOrder() async {
        let store = TestStore(initialState: PoseDetailFeature.State(poses: makePoses(1...20), selectedID: 10, followsList: true)) {
            PoseDetailFeature()
        }
        // 3번째 포즈는 상세에서 북마크를 해제해 그리드의 북마크 목록에서 빠졌습니다.
        let listPoses = makePoses(1...40).elements.filter { $0.id != 3 }
        let expectedPoses = makePoses(1...40)

        await store.send(.appendPoses(listPoses)) {
            $0.poses = expectedPoses
        }
    }

    @Test("붙인 뒤에도 끝 가까이면 다음 페이지를 다시 요청한다")
    func appendPoses_stillNearEnd_requestsMorePoses() async {
        let store = TestStore(initialState: PoseDetailFeature.State(poses: makePoses(1...20), selectedID: 20, followsList: true)) {
            PoseDetailFeature()
        }
        let expectedPoses = makePoses(1...21)

        await store.send(.appendPoses(expectedPoses.elements)) {
            $0.poses = expectedPoses
        }
        await store.receive { action in
            guard case .delegate(.requestMorePoses) = action else { return false }
            return true
        }
    }

    @Test("랜덤 포즈에서 연 상세는 그리드 목록이 받은 포즈를 붙이지 않는다")
    func appendPoses_randomPoseDetail_keepsPoses() async {
        let store = TestStore(initialState: PoseDetailFeature.State(poses: makePoses(1...20), selectedPose: makePose(id: 500), followsList: false)) {
            PoseDetailFeature()
        }

        await store.send(.appendPoses(makePoses(1...40).elements))
    }
}


// MARK: - Helpers

private extension PoseDetailFeatureTests {
    func makePose(id: PoseID) -> Pose {
        Pose(id: id, peopleCountOption: .solo, imageURL: nil, isScrapped: false, contentType: .jpeg, width: nil, height: nil)
    }

    func makePoses(_ ids: ClosedRange<PoseID>) -> IdentifiedArrayOf<Pose> {
        IdentifiedArray(uniqueElements: ids.map { makePose(id: $0) })
    }
}
