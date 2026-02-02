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
    @Dependency(\.tokenStorage) private var tokenStorage
    
    public init() {}
    
    public func login(idToken: String, provider: ProviderType) async throws(AuthRepositoryError) -> AuthTokens {
        let dto = SocialLoginDTO.Request(idToken: idToken)
        let endpoint = AuthEndpoint.login(dto: dto, provider: provider)
        
        do {
            let responseDTO: BaseResponseDTO<SocialLoginDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let tokens = responseDTO.data?.toEntity() else { throw AuthRepositoryError.networkError(.responseDecodingError) }
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
            let responseDTO: BaseResponseDTO<UserInfoDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data,
                  let providerType = ProviderType(rawValue: data.providerType)
            else { throw AuthRepositoryError.networkError(.responseDecodingError) }
            
            let profileImageURL = URL(string: data.profileImageURLString ?? "")
            return User(id: data.id, nickname: data.nickname, email: data.email, profileImageURL: profileImageURL, providerType: providerType)
        } catch let error as NetworkError {
            throw .networkError(error)
        } catch {
            throw .userNotFound
        }
    }
    
    public func withdraw() async throws(AuthRepositoryError) {
        let endpoint = AuthEndpoint.withdraw
        do {
            let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
            try tokenStorage.delete()
        } catch let error as NetworkError {
            throw .networkError(error)
        } catch let error as TokenStorageError {
            throw .userNotFound
        } catch {
            throw .unknown
        }
    }
    
    public func logout() async throws(AuthRepositoryError) {
        do {
            try tokenStorage.delete()
        } catch {
            throw .userNotFound
        }
    }
    
    public func updateProfile(nickname: String?, profileImageID: Int?) async throws(AuthRepositoryError) {
        if let nickname {
            let requestDTO = EditNicknameDTO.Request(nickname: nickname)
            let endpoint = AuthEndpoint.editNickname(dto: requestDTO)
            do {
                let _: BaseResponseDTO<EditNicknameDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            } catch let error as NetworkError {
                throw .networkError(error)
            } catch {
                throw .unknown
            }
        }
        
        if let profileImageID {
            let requestDTO = EditProfileImageDTO.Request(imageID: profileImageID)
            let endpoint = AuthEndpoint.editProfileImage(dto: requestDTO)
            do {
                let _: BaseResponseDTO<EditProfileImageDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            } catch let error as NetworkError {
                throw .networkError(error)
            } catch {
                throw .unknown
            }
        }
    }
    
    public func restoreSession() async throws(AuthRepositoryError) -> User {
        guard let tokens = try? tokenStorage.fetch() else { throw .unauthorized }
        do {
            return try await fetchUser()
        } catch {
            try? tokenStorage.delete()
            throw .unauthorized
        }
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
