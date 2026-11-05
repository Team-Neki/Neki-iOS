//
//  PushNotificationEventFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct PushNotificationEventFeatureTests {
    @Test("푸시 알림을 눌러 들어오면 페이로드에 값이 있어도 속성 없이 알림 클릭을 남긴다")
    func responseReceived_logsNotificationClickWithoutParameters() async {
        let records = LockIsolated<[String]>([])
        let store = TestStore(initialState: PushNotificationEventFeature.State()) {
            PushNotificationEventFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                records.withValue { $0.append("\(event.name.value) \(event.parameters == nil ? "속성 없음" : "속성 있음")") }
            }
        }
        let payload = PushNotificationPayload(userInfo: [
            "notification_type": "event",
            "message_tone": "friendly",
            "has_variable": "true"
        ])

        await store.send(.eventReceived(.responseReceived(payload)))
        await store.finish()

        #expect(records.value == ["notification_click 속성 없음"])
    }
}
