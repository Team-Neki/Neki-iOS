//
//  DeveloperDiagnosticsFeature.swift
//  Neki-iOS
//
//  Created by Codex on 7/7/26.
//

import ComposableArchitecture

@Reducer
struct DeveloperDiagnosticsFeature {
    @ObservableState
    struct State: Equatable {
        var diagnostics: AppDiagnostics = .empty
        var isLoading: Bool = false
    }

    enum Action {
        case onAppear
        case refreshButtonTapped
        case diagnosticsResponse(AppDiagnostics)
    }

    @Dependency(\.appDiagnosticsClient) private var appDiagnosticsClient

    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear, .refreshButtonTapped:
                state.isLoading = true
                return .run { send in
                    await send(.diagnosticsResponse(appDiagnosticsClient.fetch()))
                }

            case let .diagnosticsResponse(diagnostics):
                state.isLoading = false
                state.diagnostics = diagnostics
                return .none
            }
        }
    }
}
