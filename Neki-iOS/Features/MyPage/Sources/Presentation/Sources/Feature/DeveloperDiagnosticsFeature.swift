//
//  DeveloperDiagnosticsFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/7/26.
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

    private enum CancelID: Hashable {
        case fetchDiagnostics
    }

    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear, .refreshButtonTapped:
                state.isLoading = true
                return .run { send in
                    await send(.diagnosticsResponse(appDiagnosticsClient.fetch()))
                }
                .cancellable(id: CancelID.fetchDiagnostics, cancelInFlight: true)

            case let .diagnosticsResponse(diagnostics):
                state.isLoading = false
                state.diagnostics = diagnostics
                return .none
            }
        }
    }
}
