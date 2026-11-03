//
//  ServerLogPlatformLiveTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import Testing
import UIKit
@testable import Neki_iOS

struct ServerLogPlatformLiveTests {
    @Test("생명주기 알림 셋을 받은 순서대로 넘기고, 다른 알림은 넘기지 않는다", .timeLimit(.minutes(1)))
    func applicationLifecycle_forwardsNotificationsInOrder() async {
        let center = NotificationCenter()
        let events = UIKitApplicationLifecycle(notificationCenter: center).events()

        // 스트림을 읽기 전에 보낸 알림도 받아야 합니다.
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        var received: [ApplicationLifecycleEvent] = []
        for await event in events {
            received.append(event)
            if received.count == 3 { break }
        }

        #expect(received == [.didEnterBackground, .willEnterForeground, .didBecomeActive])
    }
}
