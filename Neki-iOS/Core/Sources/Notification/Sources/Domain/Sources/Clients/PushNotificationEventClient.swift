//
//  PushNotificationEventClient.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
public struct PushNotificationEventClient {
    public var events: @Sendable () async -> AsyncStream<PushNotificationEvent> = {
        AsyncStream { $0.finish() }
    }
}

extension PushNotificationEventClient: DependencyKey {
    public static let liveValue = PushNotificationEventClient(
        events: {
            await PushNotificationEventBroker.shared.events()
        }
    )
}

extension PushNotificationEventClient: TestDependencyKey {
    public static let testValue = PushNotificationEventClient(
        events: { AsyncStream { $0.finish() } }
    )
}

public extension DependencyValues {
    var pushNotificationEventClient: PushNotificationEventClient {
        get { self[PushNotificationEventClient.self] }
        set { self[PushNotificationEventClient.self] = newValue }
    }
}
