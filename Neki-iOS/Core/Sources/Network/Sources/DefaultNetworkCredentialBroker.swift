//
//  DefaultNetworkCredentialBroker.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/11/26.
//

import Foundation
import os

/// 자격증명 상태와 재발급·재시도를 조율하며 복구되지 않은 실패를 에러로 반환합니다.
///
/// 네트워크 요청 중 actor가 재진입할 수 있으므로 저장 결과는 요청 시작 당시 revision과 일치할 때만
/// 반영합니다. 저장소의 비교 및 변경은 suspension point 없이 처리합니다.
final actor DefaultNetworkCredentialBroker: NetworkCredentialBroker, AuthTokenDiagnosticsReading {
    private struct RefreshRequest {
        let id: UUID
        let revision: UUID
        let task: Task<TokenStorageSnapshot, Error>
    }

    private let tokenStorage: any TokenStorage

    private var refreshRequest: RefreshRequest?

    init(tokenStorage: any TokenStorage = KeychainTokenStorage(encoder: .init(), decoder: .init())) {
        self.tokenStorage = tokenStorage
    }

    var credentialGeneration: UUID { tokenStorage.credentialGeneration }

    func isCurrent(generation: UUID) -> Bool {
        tokenStorage.credentialGeneration == generation
    }

    func store(_ tokens: AuthTokens, matchingGeneration generation: UUID) throws {
        try Task.checkCancellation()
        guard tokenStorage.credentialGeneration == generation else { throw CancellationError() }
        try tokenStorage.store(tokens)
    }

    func fetchStoredTokens() throws -> AuthTokens {
        try tokenStorage.fetch()
    }

    func removeCredentials(matchingGeneration generation: UUID) throws -> Bool {
        try Task.checkCancellation()
        return try tokenStorage.delete(ifMatchingGeneration: generation)
    }

    func performAuthenticatedRequest(
        using provider: any NetworkProvider,
        generation: UUID,
        operation: @Sendable (AuthTokens) async throws -> Data
    ) async throws -> Data {
        guard tokenStorage.credentialGeneration == generation else { throw CancellationError() }
        let credentials = try await authorizedCredentials(using: provider)
        guard let tokens = credentials.tokens else { throw CancellationError() }
        do { return try await operation(tokens) }
        catch NetworkError.unauthorizedError {
            let refreshed = try await refresh(using: provider, credentials: credentials)
            guard let tokens = refreshed.tokens else { throw CancellationError() }
            do { return try await operation(tokens) }
            catch NetworkError.unauthorizedError { throw try unauthorizedFailure(refreshed) }
        }
    }
}


// MARK: - DefaultNetworkCredentialBroker + Authentication

private extension DefaultNetworkCredentialBroker {
    func authorizedCredentials(using provider: any NetworkProvider) async throws -> TokenStorageSnapshot {
        let credentials = try tokenStorage.snapshot()
        guard let tokens = credentials.tokens else {
            throw NetworkCredentialFailure(credentialGeneration: credentials.generation, reason: .credentialsUnavailable)
        }
        guard tokens.refreshNeeded else { return credentials }
        return try await refresh(using: provider, credentials: credentials)
    }

    func refresh(
        using provider: any NetworkProvider,
        credentials: TokenStorageSnapshot
    ) async throws -> TokenStorageSnapshot {
        if let refreshRequest, refreshRequest.revision == credentials.revision {
            do { return try await refreshRequest.task.value }
            catch NetworkError.unauthorizedError { throw try unauthorizedFailure(credentials) }
        }
        guard let tokens = credentials.tokens else { throw CancellationError() }
        let currentCredentials = try tokenStorage.snapshot()
        guard currentCredentials.generation == credentials.generation else { throw CancellationError() }
        guard currentCredentials.revision == credentials.revision else { return currentCredentials }

        let id = UUID()
        let task = Task {
            let newTokens = try await requestRefresh(provider: provider, tokens: tokens)
            try Task.checkCancellation()
            return try self.storeRefreshedTokens(newTokens, replacing: credentials.revision)
        }
        refreshRequest = RefreshRequest(id: id, revision: credentials.revision, task: task)
        defer {
            if refreshRequest?.id == id { refreshRequest = nil }
        }

        do { return try await task.value }
        catch NetworkError.unauthorizedError {
            throw try unauthorizedFailure(credentials)
        }
    }

    func unauthorizedFailure(_ credentials: TokenStorageSnapshot) throws -> NetworkCredentialFailure {
        guard try tokenStorage.snapshot().revision == credentials.revision else { throw CancellationError() }
        // 비교와 삭제는 동일한 actor 구간에서 완료합니다. 삭제 실패도 인증 복구 성공은 아닙니다.
        do { _ = try tokenStorage.delete(ifMatching: credentials.revision) }
        catch { Logger.data.error("Failed to remove invalid credentials: \(error.localizedDescription)") }
        return .init(credentialGeneration: tokenStorage.credentialGeneration, reason: .unauthorized)
    }

    func storeRefreshedTokens(_ tokens: AuthTokens, replacing revision: UUID) throws -> TokenStorageSnapshot {
        guard let stored = try tokenStorage.store(tokens, replacing: revision) else { throw CancellationError() }
        return stored
    }

    func requestRefresh(provider: any NetworkProvider, tokens: AuthTokens) async throws -> AuthTokens {
        let destination = NetworkEndpoint.reissueToken(dto: .init(refreshToken: tokens.refreshToken))
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
