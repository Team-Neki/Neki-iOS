//
//  AttributionFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

import AppTrackingTransparency
import ComposableArchitecture

@Reducer
struct AttributionFeature {
    @ObservableState
    struct State: Equatable {
        var isRequestingTrackingAuthorization = false
    }
    
    enum Action {
        case appLaunched
        case requestTrackingAuthorization
        case trackingAuthorizationStatusResponse(ATTrackingManager.AuthorizationStatus)
        case trackingAuthorizationRequestCompleted
        case completeRegistration
    }
    
    @Dependency(\.attributionClient) private var attributionClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appLaunched:
                return .run { _ in await attributionClient.initializeAttribution() }

            case .requestTrackingAuthorization:
                guard state.isRequestingTrackingAuthorization == false else { return .none }
                state.isRequestingTrackingAuthorization = true
                return .run { send in
                    let status = await attributionClient.checkTrackingAuthorizationStatus()
                    await send(.trackingAuthorizationStatusResponse(status))
                }

            case let .trackingAuthorizationStatusResponse(status):
                switch status {
                case .notDetermined:
                    return .run { send in
                        await attributionClient.requestTrackingAuthorization()
                        await send(.trackingAuthorizationRequestCompleted)
                    }
                case .restricted, .denied, .authorized:
                    state.isRequestingTrackingAuthorization = false
                    return .none
                @unknown default:
                    state.isRequestingTrackingAuthorization = false
                    return .none
                }

            case .trackingAuthorizationRequestCompleted:
                state.isRequestingTrackingAuthorization = false
                return .none

            case .completeRegistration:
                return .run { _ in await attributionClient.trackCompleteRegistration() }
            }
        }
    }
}
