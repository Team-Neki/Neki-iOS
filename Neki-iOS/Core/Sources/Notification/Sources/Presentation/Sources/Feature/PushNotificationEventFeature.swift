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
        case delegate(Delegate)

        enum Delegate {
            case didRegisterAPNSToken
            case didReceiveFCMRegistrationToken
        }
    }

    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

    private enum CancelID: Hashable {
        case eventStream
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .task:
                return .run { send in
                    for await event in await pushNotificationClient.events() {
                        await send(.eventReceived(event))
                    }
                }
                .cancellable(id: CancelID.eventStream, cancelInFlight: true)

            case .eventReceived(.apnsTokenRegistered):
                return .send(.delegate(.didRegisterAPNSToken))

            case .eventReceived(.fcmRegistrationTokenReceived):
                return .send(.delegate(.didReceiveFCMRegistrationToken))

            case let .eventReceived(.foregroundReceived(payload)):
                Logger.data.debug("Foreground 푸시 알림 수신: \(payload.redactedLogDescription)")
                return .none

            case let .eventReceived(.responseReceived(payload)):
                Logger.data.debug("푸시 알림 클릭 이벤트 수신: \(payload.redactedLogDescription)")
                return .run { _ in
                    await analyticsClient.logEvent(PushNotificationAnalyticsEvent.notificationClick(payload: payload))
                }

            case .delegate:
                return .none
            }
        }
    }
}

private extension PushNotificationPayload {
    var redactedLogDescription: String {
        "keys=\(values.keys.sorted().joined(separator: ","))"
    }
}
