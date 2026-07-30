//
//  AttributionFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import ComposableArchitecture

@Reducer
struct AttributionFeature {
    @ObservableState
    struct State: Equatable {}
    
    enum Action {
        case appLaunched
    }
    
    @Dependency(\.attributionClient) private var attributionClient
    
    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .appLaunched:
                return .run { _ in await attributionClient.initializeAttribution() }
            }
        }
    }
}
