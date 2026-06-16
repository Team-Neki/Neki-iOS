//
//  PushNotificationEventFeature.swift
//  Neki-iOS
//
//  Created by Codex on 6/16/26.
//

import ComposableArchitecture
import Foundation
import os

@Reducer
struct PushNotificationEventFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case task
        case eventReceived(PushNotificationEvent)
    }

    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.pushNotificationEventClient) private var eventClient

    private enum CancelID: Hashable {
        case eventStream
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .task:
                return .run { send in
                    for await event in await eventClient.events() {
                        await send(.eventReceived(event))
                    }
                }
                .cancellable(id: CancelID.eventStream, cancelInFlight: true)

            case let .eventReceived(.foregroundReceived(payload)):
                Logger.data.debug("Foreground 푸시 알림 수신: \(payload.redactedLogDescription)")
                return .none

            case let .eventReceived(.responseReceived(payload)):
                Logger.data.debug("푸시 알림 클릭 이벤트 수신: \(payload.redactedLogDescription)")
                return .run { _ in
                    analyticsClient.logEvent(PushNotificationAnalyticsEvent.notificationClick(payload: payload))
                }
            }
        }
    }
}

private extension PushNotificationPayload {
    var redactedLogDescription: String {
        "keys=\(values.keys.sorted().joined(separator: ","))"
    }
}
