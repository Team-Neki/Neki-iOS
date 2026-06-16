//
//  PushNotificationEventBroker.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import Foundation

public actor PushNotificationEventBroker {
    public static let shared = PushNotificationEventBroker()

    private var continuations: [UUID: AsyncStream<PushNotificationEvent>.Continuation] = [:]
    private var pendingEvents: [PushNotificationEvent] = []

    public func events() -> AsyncStream<PushNotificationEvent> {
        let id = UUID()

        return AsyncStream { continuation in
            Task { await self.addContinuation(continuation, id: id) }

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    public func publish(_ event: PushNotificationEvent) {
        guard continuations.isEmpty == false else {
            pendingEvents.append(event)
            return
        }

        continuations.values.forEach { $0.yield(event) }
    }

    private func addContinuation(
        _ continuation: AsyncStream<PushNotificationEvent>.Continuation,
        id: UUID
    ) {
        continuations[id] = continuation
        pendingEvents.forEach { continuation.yield($0) }
        pendingEvents.removeAll()
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
