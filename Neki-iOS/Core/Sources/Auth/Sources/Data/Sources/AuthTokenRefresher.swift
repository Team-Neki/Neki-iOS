//
//  AuthTokenRefresher.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation
import os

struct AuthTokenRefresher: TokenRefresher {
    func refresh(provider: any NetworkProvider, tokens: AuthTokens) async throws -> AuthTokens {
        let destination = AuthEndpoint.reissueToken(dto: .init(refreshToken: tokens.refreshToken))
        do {
            let dto: BaseResponseDTO<ReissueTokenDTO.Response> = try await provider.request(endpoint: destination)
            guard let data = dto.data else { throw NetworkError.networkFail }
            return AuthTokens(accessToken: data.accessToken, refreshToken: data.refreshToken)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let error = error as? NetworkError else {
                Logger.data.error("Reissue token failed with unknown error: \(error.localizedDescription)")
                throw NetworkError.unknownError(error)
            }
            Logger.data.error("Reissue token failed with error: \(error.localizedDescription)")
            throw error
        }
    }
}
