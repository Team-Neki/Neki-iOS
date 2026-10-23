//
//  MapCameraTransitionPolicyTests.swift
//  Neki-iOSTests
//
//  Created by Codex on 10/24/26.
//

import Testing
import NMapsMap
@testable import Neki_iOS

struct MapCameraTransitionPolicyTests {
    @Test(
        "카메라 이동과 함께 변경되는 지도 inset은 별도로 애니메이션하지 않는다",
        arguments: [false, true], [false, true]
    )
    func pendingCameraUpdate_disablesIndependentContentInsetAnimation(
        hasPendingCameraMove: Bool,
        hasPendingCameraFit: Bool
    ) {
        guard hasPendingCameraMove || hasPendingCameraFit else { return }
        #expect(MapCameraTransitionPolicy.animatesContentInset(
            hasPendingCameraMove: hasPendingCameraMove,
            hasPendingCameraFit: hasPendingCameraFit
        ) == false)
    }

    @Test("카메라 이동이 없는 시트 변경은 inset 애니메이션을 유지한다")
    func sheetOnlyUpdate_keepsContentInsetAnimation() {
        #expect(MapCameraTransitionPolicy.animatesContentInset(
            hasPendingCameraMove: false,
            hasPendingCameraFit: false
        ))
    }

    @Test("사용자 제스처 카메라 이동만 중간 viewport 상태를 발행한다")
    func cameraChangeReason_publishesOnlyGestureUpdates() {
        #expect(MapCameraTransitionPolicy.publishesUserInteractionUpdates(for: NMFMapChangedByGesture))
        #expect(MapCameraTransitionPolicy.publishesUserInteractionUpdates(for: NMFMapChangedByDeveloper) == false)
        #expect(MapCameraTransitionPolicy.publishesUserInteractionUpdates(for: NMFMapChangedByControl) == false)
    }
}
