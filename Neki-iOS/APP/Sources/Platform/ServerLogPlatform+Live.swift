//
//  ServerLogPlatform+Live.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Dependencies
import Foundation
import UIKit

extension ServerLogPlatformKey: DependencyKey {
    static let liveValue = ServerLogPlatform(
        lifecycle: UIKitApplicationLifecycle(),
        deviceSystem: UIKitDeviceSystem()
    )
}


// MARK: - Lifecycle

/// `UIApplication` 알림으로 앱 생명주기를 알려 줍니다.
struct UIKitApplicationLifecycle: ApplicationLifecycleObserving {
    private static let notifications: [(name: Notification.Name, event: ApplicationLifecycleEvent)] = [
        (UIApplication.willEnterForegroundNotification, .willEnterForeground),
        (UIApplication.didBecomeActiveNotification, .didBecomeActive),
        (UIApplication.didEnterBackgroundNotification, .didEnterBackground)
    ]

    var notificationCenter: NotificationCenter = .default

    func isActive() async -> Bool {
        await MainActor.run { UIApplication.shared.applicationState == .active }
    }

    /// 부를 때 바로 구독하고, 세 알림을 한 스트림에 받은 순서대로 넣습니다.
    func events() -> AsyncStream<ApplicationLifecycleEvent> {
        AsyncStream { continuation in
            let observation = NotificationObservation(
                center: notificationCenter,
                tokens: Self.notifications.map { name, event in
                    notificationCenter.addObserver(forName: name, object: nil, queue: nil) { _ in
                        continuation.yield(event)
                    }
                }
            )
            continuation.onTermination = { _ in observation.remove() }
        }
    }
}

/// 스트림이 끝나면 등록한 알림 관찰을 지웁니다.
private final class NotificationObservation: @unchecked Sendable {
    private let center: NotificationCenter
    private let tokens: [any NSObjectProtocol]

    init(center: NotificationCenter, tokens: [any NSObjectProtocol]) {
        self.center = center
        self.tokens = tokens
    }

    func remove() {
        tokens.forEach { center.removeObserver($0) }
    }
}


// MARK: - Device System

/// `UIDevice`에서 운영체제 이름과 버전을 읽습니다(Amplitude `os_name`·`os_version`과 같은 출처).
struct UIKitDeviceSystem: DeviceSystemReading {
    func read() async -> DeviceSystem {
        await MainActor.run {
            DeviceSystem(name: UIDevice.current.systemName, version: UIDevice.current.systemVersion)
        }
    }
}
