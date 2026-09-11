//
//  DefaultNetworkCredentialBroker.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/11/26.
//

import Dependencies
import Foundation
import os

/// 자격증명 상태와 재발급 작업을 중개하고 복구되지 않은 실패를 전달합니다.
///
/// 네트워크 요청 중 actor가 재진입할 수 있으므로 저장 결과는 요청 시작 당시 revision과 일치할 때만
/// 반영합니다. Broker 내부 상태의 등록, 중복 판정 및 실패 발행은 suspension point 없이 처리합니다.
final actor DefaultNetworkCredentialBroker: NetworkCredentialBroker {
    private struct RefreshRequest {
        let id: UUID
        let revision: UUID
        let task: Task<TokenStorageSnapshot, Error>
    }

    @Dependency(\.tokenStorage) private var tokenStorage

    private var refreshRequest: RefreshRequest?
    private var pendingFailure: NetworkCredentialFailure?
    private var lastPublishedRevision: UUID?
    private var continuations: [UUID: AsyncStream<NetworkCredentialFailure>.Continuation] = [:]

    var credentialGeneration: UUID { get async { await tokenStorage.credentialGeneration } }

    deinit { continuations.values.forEach { $0.finish() } }

    func isCurrent(generation: UUID) async -> Bool {
        await tokenStorage.credentialGeneration == generation
    }

    func store(_ tokens: AuthTokens) async throws {
        try await tokenStorage.store(tokens)
    }

    func fetchStoredTokens() async throws -> AuthTokens {
        try await tokenStorage.fetch()
    }

    func removeCredentials(matchingRevision revision: UUID) async throws -> Bool {
        try await tokenStorage.delete(ifMatching: revision)
    }

    func removeCredentials(matchingGeneration generation: UUID) async throws -> Bool {
        try await tokenStorage.delete(ifMatchingGeneration: generation)
    }

    func authorizedCredentials(using provider: any NetworkProvider) async throws -> TokenStorageSnapshot {
        let credentials = try await tokenStorage.snapshot()
        guard let tokens = credentials.tokens else {
            publish(.init(credentialRevision: credentials.revision, reason: .credentialsUnavailable))
            throw NetworkError.unauthorizedError
        }
        guard tokens.refreshNeeded else { return credentials }
        return try await refresh(using: provider, credentials: credentials)
    }

    func refresh(
        using provider: any NetworkProvider,
        credentials: TokenStorageSnapshot
    ) async throws -> TokenStorageSnapshot {
        if let refreshRequest, refreshRequest.revision == credentials.revision { return try await refreshRequest.task.value }
        guard let tokens = credentials.tokens else { throw CancellationError() }
        let currentCredentials = try await tokenStorage.snapshot()
        guard currentCredentials.generation == credentials.generation else { throw CancellationError() }
        guard currentCredentials.revision == credentials.revision else { return currentCredentials }
        if let refreshRequest, refreshRequest.revision == credentials.revision { return try await refreshRequest.task.value }

        let id = UUID()
        let tokenStorage = self.tokenStorage
        let task = Task {
            let newTokens = try await Self.requestRefresh(provider: provider, tokens: tokens)
            try Task.checkCancellation()
            guard let stored = try await tokenStorage.store(newTokens, replacing: credentials.revision) else { throw CancellationError() }
            return stored
        }
        refreshRequest = RefreshRequest(id: id, revision: credentials.revision, task: task)
        defer {
            if refreshRequest?.id == id { refreshRequest = nil }
        }

        do { return try await task.value }
        catch NetworkError.unauthorizedError {
            await reportUnauthorized(credentials)
            throw NetworkError.unauthorizedError
        }
    }

    func reportUnauthorized(_ credentials: TokenStorageSnapshot) async {
        guard let current = try? await tokenStorage.snapshot(), current.revision == credentials.revision else { return }
        publish(.init(credentialRevision: credentials.revision, reason: .unauthorized))
    }

    func failures() -> AsyncStream<NetworkCredentialFailure> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<NetworkCredentialFailure>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        if let pendingFailure {
            continuation.yield(pendingFailure)
            self.pendingFailure = nil
        }
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id: id) }
        }
        return stream
    }

    private func publish(_ failure: NetworkCredentialFailure) {
        guard lastPublishedRevision != failure.credentialRevision else { return }
        lastPublishedRevision = failure.credentialRevision
        guard continuations.isEmpty == false else {
            pendingFailure = failure
            return
        }
        continuations.values.forEach { $0.yield(failure) }
    }

    private func removeContinuation(id: UUID) { continuations[id] = nil }

    private static func requestRefresh(provider: any NetworkProvider, tokens: AuthTokens) async throws -> AuthTokens {
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

private enum NetworkCredentialBrokerKey: DependencyKey {
    static let liveValue: any NetworkCredentialBroker = DefaultNetworkCredentialBroker()
}

private enum NetworkProviderKey: DependencyKey {
    static let liveValue: any NetworkProvider = {
        @Dependency(\.networkCredentialBroker) var credentialBroker
        return DefaultNetworkProvider(credentialBroker: credentialBroker)
    }()
}

extension DependencyValues {
    var networkCredentialBroker: any NetworkCredentialBroker {
        get { self[NetworkCredentialBrokerKey.self] }
        set { self[NetworkCredentialBrokerKey.self] = newValue }
    }

    var networkProvider: any NetworkProvider {
        get { self[NetworkProviderKey.self] }
        set { self[NetworkProviderKey.self] = newValue }
    }
}
