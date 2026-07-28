//
//  PushNotificationListFeature.swift
//  Neki-iOS
//
//  Created by Codex on 6/14/26.
//

import ComposableArchitecture

@Reducer
struct PushNotificationListFeature {
    @ObservableState
    struct State: Equatable {
        var notifications: [PushNotificationListItem] = []
        var isLoading: Bool = false
        var didLoad: Bool = false
    }

    enum Action {
        case onAppear
        case notificationListResponse(Result<[PushNotificationListItem], Error>)
        case closeButtonTapped
    }

    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.didLoad == false, state.isLoading == false else { return .none }
                state.isLoading = true
                return .run { send in
                    await send(.notificationListResponse(
                        Result { try await pushNotificationClient.fetchNotificationList() }
                    ))
                }

            case let .notificationListResponse(.success(notifications)):
                state.isLoading = false
                state.didLoad = true
                state.notifications = notifications
                return .none

            case .notificationListResponse(.failure):
                state.isLoading = false
                state.didLoad = true
                return .none

            case .closeButtonTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
