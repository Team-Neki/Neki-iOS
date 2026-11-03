//
//  ServerLogPlatform.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Dependencies
import Foundation

/// 서버 로그가 쓰는 앱 생명주기, background task, 기기 정보
/// - Note: Data 계층에는 계약만 둡니다. UIKit 구현은 APP 계층(`ServerLogPlatform+Live`)이 `liveValue`로 채웁니다.
struct ServerLogPlatform: Sendable {
    var lifecycle: any ApplicationLifecycleObserving
    var backgroundTask: any ServerLogBackgroundTaskStarting
    var deviceSystem: any DeviceSystemReading
}

enum ServerLogPlatformKey: TestDependencyKey {
    static let testValue = ServerLogPlatform(
        lifecycle: InactiveApplicationLifecycle(),
        backgroundTask: NoBackgroundTask(),
        deviceSystem: UnknownDeviceSystem()
    )
}

extension DependencyValues {
    var serverLogPlatform: ServerLogPlatform {
        get { self[ServerLogPlatformKey.self] }
        set { self[ServerLogPlatformKey.self] = newValue }
    }
}


// MARK: - Lifecycle

enum ApplicationLifecycleEvent: Sendable {
    case willEnterForeground
    case didBecomeActive
    case didEnterBackground
}

/// 앱이 포그라운드·백그라운드로 바뀌는 것을 알려 줍니다(Amplitude-Swift `IOSLifecycleMonitor`).
protocol ApplicationLifecycleObserving: Sendable {
    /// 지금 앱이 활성 상태인지
    func isActive() async -> Bool
    /// 부른 뒤에 생긴 생명주기 변화를 생긴 순서대로 줍니다.
    func events() -> AsyncStream<ApplicationLifecycleEvent>
}

/// 활성 상태가 아니고 아무 변화도 알리지 않는 생명주기(테스트 기본값)
private struct InactiveApplicationLifecycle: ApplicationLifecycleObserving {
    func isActive() async -> Bool { false }
    func events() -> AsyncStream<ApplicationLifecycleEvent> { AsyncStream { $0.finish() } }
}


// MARK: - Background Task

/// 업로드하는 동안 앱이 백그라운드로 가도 잠시 이어서 보낼 수 있게 합니다(SDK의 업로드별 background task).
protocol ServerLogBackgroundTaskStarting: Sendable {
    /// 업로드를 마치면 돌려받은 클로저를 불러 끝냅니다.
    func begin() async -> @Sendable () async -> Void
}

/// 아무것도 하지 않는 background task(테스트 기본값)
private struct NoBackgroundTask: ServerLogBackgroundTaskStarting {
    func begin() async -> @Sendable () async -> Void { {} }
}


// MARK: - Device System

/// 운영체제 이름과 버전(`UIDevice`의 `systemName`·`systemVersion`)
struct DeviceSystem: Equatable, Sendable {
    let name: String
    let version: String
}

protocol DeviceSystemReading: Sendable {
    func read() async -> DeviceSystem
}

/// 알 수 없는 기기(테스트 기본값)
private struct UnknownDeviceSystem: DeviceSystemReading {
    func read() async -> DeviceSystem { DeviceSystem(name: "", version: "") }
}
