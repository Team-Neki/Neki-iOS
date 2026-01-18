//
//  AuthTokenRefresher.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

struct AuthTokenRefresher: TokenRefresher {
    var destination: Endpoint { AuthEndpoint.reissueToken }
    
    func refresh(provider: any NetworkProvider) async throws(NetworkError) -> AuthTokens {
        do {
            let tokens: AuthTokens = try await provider.request(endpoint: destination)
            return tokens
        } catch {
            guard let error = error as? NetworkError else { throw .unknownError }
            throw error
        }
    }
}
