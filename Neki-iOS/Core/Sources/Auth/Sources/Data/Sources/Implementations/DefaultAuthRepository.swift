//
//  DefaultAuthRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation
import Dependencies
import os

public final actor DefaultAuthRepository: AuthRepository {
    private enum Constants {
        static let marketingTermType = "MARKETING"
    }

    @Dependency(\.networkProvider) private var networkProvider
    @Dependency(\.tokenStorage) private var tokenStorage
    @Dependency(\.networkRequestFailureEvents) private var requestFailureEvents
    
    public init() {}

    public func credentialFailures() -> AsyncStream<AuthCredentialFailure> {
        let failures = requestFailureEvents.failures()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                defer { continuation.finish() }
                for await failure in failures {
                    guard Task.isCancelled == false else { return }
                    let reason: AuthCredentialFailure.Reason
                    switch failure.reason {
                    case .credentialsUnavailable: reason = .missingCredentials
                    case .unauthorized: reason = .rejectedCredentials
                    }
                    continuation.yield(.init(revision: failure.credentialRevision, reason: reason))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func removeCredentials(matching failure: AuthCredentialFailure) async -> AuthCredentialFailure.RemovalResult {
        do {
            return try await tokenStorage.delete(ifMatching: failure.revision) ? .removed : .superseded
        } catch {
            Logger.data.error("Failed to remove invalid credentials: \(error.localizedDescription)")
            return .storageFailure
        }
    }
    
    public func login(idToken: String, provider: ProviderType) async throws(AuthRepositoryError) -> (tokens: AuthTokens, registrationStatus: RegistrationStatus) {
        let platformParameter: String = "ios"
            
        let dto = SocialLoginDTO.Request(idToken: idToken, platform: platformParameter)
        let endpoint = AuthEndpoint.login(dto: dto, provider: provider)
        
        do {
            let responseDTO: BaseResponseDTO<SocialLoginDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
            let tokens = data.toEntity()
            try await tokenStorage.store(tokens)
            let registrationStatus: RegistrationStatus = data.isNewUser ? .newlyRegistered : .existingAccount
            return (tokens, registrationStatus)
        } catch { throw mapError(error) }
    }
    
    public func fetchUser() async throws(AuthRepositoryError) -> User {
        let endpoint = AuthEndpoint.fetchUserInfo
        
        do {
            let responseDTO: BaseResponseDTO<UserInfoDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data,
                  let providerType = ProviderType(rawValue: data.providerType.lowercased())
            else { throw NetworkError.responseDecodingError }
            
            let profileImageURL = URL(string: data.profileImageURLString ?? "")
            return User(
                id: data.id,
                nickname: data.nickname,
                email: data.email,
                profileImageURL: profileImageURL,
                providerType: providerType,
                allRequiredTermsAgreed: data.agreedTerms,
                marketingTermAgreed: data.marketingTerm,
                pushNotificationAgreed: data.pushNotificationAgreed
            )
        } catch { throw mapError(error) }
    }
    
    public func withdraw() async throws(AuthRepositoryError) {
        let generation = await tokenStorage.credentialGeneration
        let endpoint = AuthEndpoint.withdraw
        do {
            let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
            let currentGeneration = await tokenStorage.credentialGeneration
            guard generation == currentGeneration else { throw AuthRepositoryError.unauthorized }
            try await tokenStorage.delete()
        } catch is TokenStorageError {
            throw .userNotFound
        } catch { throw mapError(error) }
    }
    
    public func logout() async throws(AuthRepositoryError) {
        let generation = await tokenStorage.credentialGeneration
        let endpoint = AuthEndpoint.logout
        do {
            let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
            let currentGeneration = await tokenStorage.credentialGeneration
            guard generation == currentGeneration else { throw AuthRepositoryError.unauthorized }
            try await tokenStorage.delete()
        } catch is TokenStorageError {
            throw .userNotFound
        } catch { throw mapError(error) }
    }
    
    public func updateProfile(nickname: String?, editAction: ProfileImageEditAction) async throws(AuthRepositoryError) -> Void {
        if let nickname {
            let requestDTO = EditNicknameDTO.Request(nickname: nickname)
            let endpoint = AuthEndpoint.editNickname(dto: requestDTO)
            do {
                let _: BaseResponseDTO<EditNicknameDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            } catch { throw mapError(error) }
        }
        
        switch editAction {
        case let .update(imageID): try await requestUpdateProfileImage(id: imageID)
        case .delete: try await requestUpdateProfileImage(id: nil)
        case .keep: break
        }
    }
    
    public func restoreSession() async throws(AuthRepositoryError) -> User {
        try await fetchUser()
    }

    public func fetchStoredTokens() async -> AuthTokens? {
        try? await tokenStorage.fetch()
    }

    public func fetchTerms() async throws(AuthRepositoryError) -> [Term] {
        try await fetchTermDTOs().map { $0.toEntity() }
    }
    
    public func agreeWithTerms(agreements: [UserAgreement]) async throws(AuthRepositoryError) {
        let agreements = agreements.map { AgreementsDTO(termID: $0.id, agreed: $0.isAgreed) }
        try await requestTermsAgreement(agreements)
    }

    public func updateMarketingConsent(isAgreed: Bool) async throws(AuthRepositoryError) {
        let terms = try await fetchTermDTOs()
        guard let marketingTerm = terms.first(where: {
            $0.termType?.caseInsensitiveCompare(Constants.marketingTermType) == .orderedSame
        }) else {
            throw .unknown
        }

        try await requestTermsAgreement([
            AgreementsDTO(termID: marketingTerm.id, agreed: isAgreed)
        ])
    }
}


// MARK: - DefaultAuthRepository + Helpers

private extension DefaultAuthRepository {
    func mapError(_ error: Error) -> AuthRepositoryError {
        switch error {
        case let error as AuthRepositoryError: return error
        case is CancellationError: return .cancelled
        case let error as NetworkError:
            switch error {
            case .unauthorizedError: return .unauthorized
            case .networkFail: return .networkConnectionLost
            default: return .serverError(error.localizedDescription)
            }
        default: return .unknown
        }
    }

    func fetchTermDTOs() async throws(AuthRepositoryError) -> [TermDTO] {
        let endpoint = AuthEndpoint.fetchTerms

        do {
            let responseDTO: BaseResponseDTO<FetchTermsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
            return data.terms
        } catch { throw mapError(error) }
    }

    func requestTermsAgreement(_ agreements: [AgreementsDTO]) async throws(AuthRepositoryError) {
        let dto = AgreeTermsDTO.Request(agreements: agreements)
        let endpoint = AuthEndpoint.agreeWithTerms(dto: dto)
        
        do {
            let _: BaseResponseDTO<AgreeTermsDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        } catch { throw mapError(error) }
    }

    func requestUpdateProfileImage(id: ProfileImageEditAction.ImageID?) async throws(AuthRepositoryError) {
        let requestDTO = EditProfileImageDTO.Request(imageID: id)
        let endpoint = AuthEndpoint.editProfileImage(dto: requestDTO)
        
        do {
            let _: BaseResponseDTO<EditProfileImageDTO.Response> = try await networkProvider.request(endpoint: endpoint)
        } catch { throw mapError(error) }
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
