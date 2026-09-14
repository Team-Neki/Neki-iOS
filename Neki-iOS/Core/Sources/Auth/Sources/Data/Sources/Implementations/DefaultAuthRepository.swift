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

    private var pendingCredentialFailure: AuthCredentialFailure?
    private var lastPublishedCredentialGeneration: UUID?
    private var credentialFailureContinuations: [UUID: AsyncStream<AuthCredentialFailure>.Continuation] = [:]
    private var credentialFailureValidation: (@Sendable () async -> Bool)?

    @Dependency(\.networkProvider) private var networkProvider
    
    public init() {}

    deinit { credentialFailureContinuations.values.forEach { $0.finish() } }

    public func isCurrentSession(matching failure: AuthCredentialFailure) async throws(AuthRepositoryError) -> Bool {
        guard lastPublishedCredentialGeneration == failure.generation,
              let credentialFailureValidation else { return false }
        guard await credentialFailureValidation() else { return false }
        return lastPublishedCredentialGeneration == failure.generation
    }
    
    public func login(idToken: String, provider: ProviderType) async throws(AuthRepositoryError) -> (tokens: AuthTokens, registrationStatus: RegistrationStatus) {
        let platformParameter: String = "ios"
            
        let dto = SocialLoginDTO.Request(idToken: idToken, platform: platformParameter)
        let endpoint = AuthEndpoint.login(dto: dto, provider: provider)
        
        do {
            let responseDTO: BaseResponseDTO<SocialLoginDTO.Response> = try await networkProvider.request(endpoint: endpoint)
            guard let data = responseDTO.data else { throw NetworkError.responseDecodingError }
            let tokens = data.toEntity()
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
        let endpoint = AuthEndpoint.withdraw
        do {
            let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
        } catch is TokenStorageError {
            throw .userNotFound
        } catch { throw mapError(error) }
    }
    
    public func logout() async throws(AuthRepositoryError) {
        let endpoint = AuthEndpoint.logout
        do {
            let _: BaseResponseDTO<EmptyData> = try await networkProvider.request(endpoint: endpoint)
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


// MARK: - DefaultAuthRepository + AuthCredentialFailureHandling

extension DefaultAuthRepository {
    public func reportCredentialFailure(
        _ failure: AuthCredentialFailure,
        isCurrent: @escaping @Sendable () async -> Bool
    ) async {
        // 유효성 확인 중 다른 실패가 반영되었다면 재검증해 오래된 결과의 역전 반영을 막습니다.
        while true {
            let previousGeneration = lastPublishedCredentialGeneration
            guard await isCurrent() else { return }
            guard previousGeneration == lastPublishedCredentialGeneration else { continue }
            guard lastPublishedCredentialGeneration != failure.generation else { return }
            lastPublishedCredentialGeneration = failure.generation
            credentialFailureValidation = isCurrent
            // 구독 교체 도중 소비되지 않은 실패도 다음 구독에서 다시 확인할 수 있도록 한 건만 유지합니다.
            pendingCredentialFailure = failure
            credentialFailureContinuations.values.forEach { $0.yield(failure) }
            return
        }
    }

    public func credentialFailures() -> AsyncStream<AuthCredentialFailure> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AuthCredentialFailure>.makeStream(bufferingPolicy: .bufferingNewest(1))
        credentialFailureContinuations[id] = continuation
        if let pendingCredentialFailure { continuation.yield(pendingCredentialFailure) }
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeCredentialFailureContinuation(id: id) }
        }
        return stream
    }
}


// MARK: - DefaultAuthRepository + Helpers

private extension DefaultAuthRepository {
    func removeCredentialFailureContinuation(id: UUID) { credentialFailureContinuations[id] = nil }

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
