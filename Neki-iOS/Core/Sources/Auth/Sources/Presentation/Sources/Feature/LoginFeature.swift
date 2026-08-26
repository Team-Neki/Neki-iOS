//
//  LoginFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import Foundation
import ComposableArchitecture
import AuthenticationServices
import os

@Reducer
public struct LoginFeature {
    @ObservableState
    public struct State {
        var isLoading = false
        var advertisingTrackingAuthorizationPhase: AdvertisingTrackingAuthorizationPhase = .idle
    }
    
    public enum Action {
        // View Actions
        case onAppear
        case kakaoLogin
        case appleLogin(Result<ASAuthorization, any Error>)
        case handleKakaoOpenURL(URL)
        
        // Delegate Actions
        case loginResponse(Result<AuthLoginResult, Error>)
        case trackingAuthorizationResolved
    }
    
    @Dependency(\.authClient) private var authClient
    @Dependency(\.attributionClient) private var attributionClient
    
    public var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .onAppear:
                guard state.advertisingTrackingAuthorizationPhase == .idle else { return .none }
                state.advertisingTrackingAuthorizationPhase = .resolving
                return .run { send in
                    _ = await attributionClient.resolveTrackingAuthorization()
                    await send(.trackingAuthorizationResolved)
                }

            case .kakaoLogin:
                guard state.advertisingTrackingAuthorizationPhase == .resolved else { return .none }
                guard state.isLoading == false else { return .none }
                state.isLoading = true
                return .run { send in
                    do {
                        let loginResult = try await authClient.loginWithKakao()
                        if loginResult.registrationStatus == .newlyRegistered {
                            await attributionClient.trackCompleteRegistration()
                        }
                        await send(.loginResponse(.success(loginResult)))
                    } catch {
                        await send(.loginResponse(.failure(error)))
                    }
                }
                
            case let .appleLogin(.success(authorization)):
                guard state.advertisingTrackingAuthorizationPhase == .resolved else { return .none }
                guard state.isLoading == false else { return .none }
                guard let auth = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let idToken = auth.identityToken
                else {
                    Logger.presentation.error("ID Token이 비어있습니다.")
                    return .none
                }
                state.isLoading = true
                return .run { send in
                    do {
                        let loginResult = try await authClient.loginWithApple(idToken: idToken)
                        if loginResult.registrationStatus == .newlyRegistered {
                            await attributionClient.trackCompleteRegistration()
                        }
                        await send(.loginResponse(.success(loginResult)))
                    } catch {
                        await send(.loginResponse(.failure(error)))
                    }
                }

            case .loginResponse:
                state.isLoading = false
                return .none

            case .trackingAuthorizationResolved:
                state.advertisingTrackingAuthorizationPhase = .resolved
                return .none
                
            case let .handleKakaoOpenURL(url):
                authClient.handleKakaoOpenURL(url: url)
                return .none
                
            default:
                return .none
            }
        }
    }
}
