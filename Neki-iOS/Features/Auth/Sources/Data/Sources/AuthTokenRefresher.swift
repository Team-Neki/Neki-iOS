//
//  AuthTokenRefresher.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation
import os

struct AuthTokenRefresher: TokenRefresher {
    var destination: Endpoint { AuthEndpoint.reissueToken }
    
    func refresh(provider: any NetworkProvider) async throws(NetworkError) -> AuthTokens {
        do {
            let dto: BaseResponseDTO<ReissueTokenDTO.Response> = try await provider.request(endpoint: destination)
            guard let data = dto.data else { throw NetworkError.networkFail }
            return AuthTokens(accessToken: data.accessToken, refreshToken: data.refreshToken)
        } catch {
            guard let error = error as? NetworkError else {
                Logger.data.error("Reisue token failed with unknown error: \(error.localizedDescription)")
                throw .unknownError(error)
            }
            Logger.data.error("Reissue token failed with error: \(error.localizedDescription)")
            throw error
        }
    }
}
