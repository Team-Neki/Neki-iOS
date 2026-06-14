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
    struct State: Equatable {}

    enum Action {
        case closeButtonTapped
    }

    @Dependency(\.dismiss) private var dismiss

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .closeButtonTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
