//
//  ServerLogPlatform+Live.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Dependencies
import Foundation
import Network
import UIKit

extension ServerLogPlatformKey: DependencyKey {
    static let liveValue = ServerLogPlatform(
        lifecycle: UIKitApplicationLifecycle(),
        backgroundTask: UIKitBackgroundTask(),
        deviceSystem: UIKitDeviceSystem(),
        networkPath: NWPathMonitorNetworkPath()
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


// MARK: - Background Task

/// 업로드마다 `UIApplication` background task를 겁니다.
struct UIKitBackgroundTask: ServerLogBackgroundTaskStarting {
    func begin() async -> @Sendable () async -> Void {
        let task = await MainActor.run {
            let task = BackgroundTask()
            task.begin()
            return task
        }
        return { await task.end() }
    }

    @MainActor
    private final class BackgroundTask {
        private var identifier: UIBackgroundTaskIdentifier = .invalid

        func begin() {
            identifier = UIApplication.shared.beginBackgroundTask(withName: "ServerLogUpload") { [weak self] in
                self?.end()
            }
        }

        func end() {
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
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


// MARK: - Network Path

/// `NWPathMonitor`로 네트워크 경로를 알려 줍니다(Amplitude-Swift `PathCreation`과 같은 출처).
struct NWPathMonitorNetworkPath: NetworkPathObserving {
    /// 부를 때 감시를 시작하고, 스트림이 끝나면 멈춥니다. `NWPathMonitor`는 시작하자마자 지금 경로를 한 번 알립니다.
    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.neki.analytics.network"))
        }
    }
}
