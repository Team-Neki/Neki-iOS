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
        
    }
    
    public enum Action {
        // View Actions
        case kakaoLogin
        case appleLogin(Result<ASAuthorization, any Error>)
        case handleKakaoOpenURL(URL)
        
        // Delegate Actions
        case loginResponse(Result<User, Error>)
    }
    
    @Dependency(\.authClient) private var authClient
    
    public var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .kakaoLogin:
                return .run { send in
                    await send(.loginResponse(Result { try await authClient.loginWithKakao() }))
                }
                
            case let .appleLogin(.success(authorization)):
                guard let auth = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let idToken = auth.identityToken
                else {
                    Logger.presentation.error("ID Token이 비어있습니다.")
                    return .none
                }
                
                return .run { send in
                    await send(.loginResponse(Result { try await authClient.loginWithApple(idToken: idToken) }))
                }
                
            case let .handleKakaoOpenURL(url):
                authClient.handleKakaoOpenURL(url: url)
                return .none
                
            default:
                return .none
            }
        }
    }
}
