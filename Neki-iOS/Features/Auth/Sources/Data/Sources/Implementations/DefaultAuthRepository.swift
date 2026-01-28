//
//  DefaultAuthRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation
import Dependencies
import os

public struct DefaultAuthRepository: AuthRepository {
    @Dependency(\.networkProvider) private var networkProvider
    
    public func login(idToken: String, provider: ProviderType) async throws(AuthRepositoryError) -> AuthTokens {
        let dto = SocialLoginDTO.Request(idToken: idToken)
        let endpoint = AuthEndpoint.login(dto: dto, provider: provider)
        
        do {
            let response: BaseResponseDTO<SocialLoginDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let tokens = response.data?.toEntity() else { throw AuthRepositoryError.decodingError }
            return tokens
        } catch let error as NetworkError {
            throw .networkError(error)
        } catch {
            throw .unauthorized
        }
    }
    
    public func fetchUser() async throws(AuthRepositoryError) -> User {
        let endpoint = AuthEndpoint.fetchUserInfo
        
        do {
            let response: BaseResponseDTO<UserInfoDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let nickname = response.data?.nickname,
                  let providerIdentifier = response.data?.providerType,
                  let providerType = ProviderType(rawValue: providerIdentifier)
            else { throw AuthRepositoryError.decodingError }
            return User(nickname: nickname, providerType: providerType)
        } catch let error as NetworkError {
            throw .networkError(error)
        } catch {
            throw .userNotFound
        }
    }
    
    public func withdraw() async throws(AuthRepositoryError) {
        // TODO: API is WIP
    }
    
    public func logout() async throws(AuthRepositoryError) {
        // TODO: API is WIP
    }
    
    public func updateProfile(nickname: String?, profileImage: Data?) async throws(AuthRepositoryError) {
        // TODO: API is WIP
    }
}


// MARK: - DefaultAuthRepository + DependencyKey

private enum AuthRepositoryKey: DependencyKey {
    static let liveValue: AuthRepository = DefaultAuthRepository()
}


// MARK: - DefaultAuthRepository + Accessor

extension DependencyValues {
    var authRepository: AuthRepository {
        get { self[AuthRepositoryKey.self] }
        set { self[AuthRepositoryKey.self] = newValue }
    }
}
