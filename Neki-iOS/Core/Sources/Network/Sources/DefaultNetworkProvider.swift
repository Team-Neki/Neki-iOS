//
//  DefaultNetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import Dependencies
import DependenciesMacros
import os

public final actor DefaultNetworkProvider: NetworkProvider {
    
    private struct TokenRefreshRequest {
        let id: UUID
        let revision: UUID
        let task: Task<TokenStorageSnapshot, Error>
    }

    private var refreshRequest: TokenRefreshRequest?
    
    private let session: URLSessionProtocol
    private let tokenRefresher: TokenRefresher?
    private let decoder: JSONDecoder
    
    @Dependency(\.tokenStorage) private var tokenStorage
    @Dependency(\.networkRequestFailureEvents) private var requestFailureEvents
    
    public init(
        session: URLSessionProtocol = URLSession.shared,
        refresher: TokenRefresher? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        decoder.dateDecodingStrategy = .formatted(formatter)
        self.decoder = decoder
        self.tokenRefresher = refresher
    }
    
    /// 네트워크 요청을 수행하고 별도의 응답 데이터 없이 성공 여부만 판단합니다.
    /// 임시 구현 - Presigned URL 요청 시에만 사용합니다
    public func requestVoid(endpoint: Endpoint) async throws -> Void {
        guard endpoint.authorizationType == .none else {
            _ = try await performDataRequest(endpoint: endpoint, retryCount: 1)
            return
        }
        // Presigned URL 업로드의 기존 응답/오류 계약은 변경하지 않습니다.
        let request = try buildRequest(for: endpoint, tokens: nil)
        requestLog(request)
        do {
            let (_, response) = try await session.data(for: request, delegate: nil)
            responseLog(data: Data(), response: response)
            guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.responseError }
            guard (200..<300).contains(httpResponse.statusCode) else { throw NetworkError.networkFail }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw NetworkError.unknownError(error)
        }
    }
    
    /// 네트워크 요청을 수행하고 성공 여부만 판단하며 BaseResponseDTO<EmptyData>를 반환합니다
    @discardableResult
    public func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        try await performRequest(endpoint: endpoint, retryCount: 1)
    }
    
    /// 네트워크 요청을 수행하고 제네릭 타입으로 응답 데이터를 디코딩합니다.
    public func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        try await performRequest(endpoint: endpoint, retryCount: 1)
    }
}


// MARK: - Core Logics

private extension DefaultNetworkProvider {
    func performRequest<T: Decodable>(endpoint: Endpoint, retryCount: Int) async throws -> BaseResponseDTO<T> {
        let generation = await tokenStorage.credentialGeneration
        do {
            let data = try await performDataRequest(endpoint: endpoint, retryCount: retryCount, generation: generation)
            try Task.checkCancellation()
            try await verifyAuthorizationGeneration(generation, for: endpoint)
            return try decode(data: data)
        } catch {
            try Task.checkCancellation()
            try await verifyAuthorizationGeneration(generation, for: endpoint)
            throw error
        }
    }

    func performDataRequest(endpoint: Endpoint, retryCount: Int, generation: UUID? = nil) async throws -> Data {
        try Task.checkCancellation()
        let requestGeneration: UUID
        if let generation { requestGeneration = generation } else { requestGeneration = await tokenStorage.credentialGeneration }
        try await verifyAuthorizationGeneration(requestGeneration, for: endpoint)
        let credentials = try await authorizedCredentials(for: endpoint)
        try Task.checkCancellation()
        try await verifyAuthorizationGeneration(requestGeneration, for: endpoint)
        let request = try buildRequest(for: endpoint, tokens: credentials?.tokens)
        let (data, response) = try await executeSession(with: request)
        try Task.checkCancellation()
        try await verifyAuthorizationGeneration(requestGeneration, for: endpoint)

        switch validateResponse(response) {
        case .success: return data
        case .unauthorized:
            guard endpoint.authorizationType == .bearer, let credentials else { throw NetworkError.unauthorizedError }
            guard retryCount > .zero else {
                await publishUnauthorizedRequest(credentials)
                throw NetworkError.unauthorizedError
            }
            // 다른 요청이 이미 재발급했다면 현재 토큰으로 재시도하고 중복 재발급하지 않습니다.
            if try await tokenStorage.snapshot().revision == credentials.revision { _ = try await performTokenRefresh(credentials) }
            return try await performDataRequest(endpoint: endpoint, retryCount: retryCount - 1, generation: requestGeneration)
        case .failure(let error): throw error
        }
    }
    
    func executeSession(with request: URLRequest) async throws -> (Data, URLResponse) {
        requestLog(request)
        
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            responseLog(data: data, response: response)
            return (data, response)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw NetworkError.unknownError(error)
        }
    }
}


// MARK: - Build Request

private extension DefaultNetworkProvider {
    func buildRequest(for endpoint: Endpoint, tokens: AuthTokens?) throws -> URLRequest {
        var request = try endpoint.asURLRequest()
        if let tokens { request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization") }
        return request
    }
}


// MARK: - Auth Retry Logic

private extension DefaultNetworkProvider {
    func verifyAuthorizationGeneration(_ generation: UUID, for endpoint: Endpoint) async throws {
        guard endpoint.authorizationType != .none else { return }
        let currentGeneration = await tokenStorage.credentialGeneration
        guard generation == currentGeneration else { throw CancellationError() }
    }

    func authorizedCredentials(for endpoint: Endpoint) async throws -> TokenStorageSnapshot? {
        guard endpoint.authorizationType == .bearer else { return nil }
        let credentials = try await tokenStorage.snapshot()
        guard let tokens = credentials.tokens else {
            requestFailureEvents.publish(.init(credentialRevision: credentials.revision, reason: .credentialsUnavailable))
            throw NetworkError.unauthorizedError
        }
        guard tokens.refreshNeeded else { return credentials }
        return try await performTokenRefresh(credentials)
    }

    func performTokenRefresh(_ credentials: TokenStorageSnapshot) async throws -> TokenStorageSnapshot {
        if let refreshRequest, refreshRequest.revision == credentials.revision { return try await refreshRequest.task.value }
        guard let tokens = credentials.tokens,
              try await tokenStorage.snapshot().revision == credentials.revision else { throw CancellationError() }
        if let refreshRequest, refreshRequest.revision == credentials.revision { return try await refreshRequest.task.value }
        let id = UUID()
        let task = Task {
            guard let refresher = tokenRefresher else { throw NetworkError.networkFail }
            do {
                let newTokens = try await refresher.refresh(provider: self, tokens: tokens)
                try Task.checkCancellation()
                guard let stored = try await tokenStorage.store(newTokens, replacing: credentials.revision) else { throw CancellationError() }
                return stored
            } catch NetworkError.unauthorizedError {
                await publishUnauthorizedRequest(credentials)
                throw NetworkError.unauthorizedError
            }
        }
        refreshRequest = TokenRefreshRequest(id: id, revision: credentials.revision, task: task)
        defer {
            if refreshRequest?.id == id { refreshRequest = nil }
        }
        return try await task.value
    }

    func publishUnauthorizedRequest(_ credentials: TokenStorageSnapshot) async {
        guard let current = try? await tokenStorage.snapshot(), current.revision == credentials.revision else { return }
        requestFailureEvents.publish(.init(credentialRevision: credentials.revision, reason: .unauthorized))
    }
}


// MARK: - Validate & Decode

private extension DefaultNetworkProvider {
    enum ResponseStatus {
        case success
        case unauthorized
        case failure(NetworkError)
    }
    
    func validateResponse(_ response: URLResponse) -> ResponseStatus {
        guard let httpResponse = response as? HTTPURLResponse else { return .failure(.responseError) }
        
        switch httpResponse.statusCode {
        case 200..<300: return .success
        case 400: return .failure(.badRequestError)
        case 401: return .unauthorized
        case 404: return .failure(.notFound)
        case 500..<600: return .failure(.internalServerError)
        default: return .failure(.networkFail)
        }
    }
    
    func decode<T: Decodable>(data: Data) throws -> BaseResponseDTO<T> {
        do {
            return try self.decoder.decode(BaseResponseDTO<T>.self, from: data)
        } catch {
            Logger.network.error("❌ Decoding Error: \(error.localizedDescription)")
            throw NetworkError.responseDecodingError
        }
    }
}


// MARK: - Request & Response Log

private extension DefaultNetworkProvider {
    func requestLog(_ request: URLRequest) {
        Logger.network.debug("➡️ [REQUEST] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields {
            Logger.network.debug("🧾 Request Headers: \(headers.description)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            Logger.network.debug("📦 Request Body: \(bodyString)")
        }
    }
    
    func responseLog(data: Data, response: URLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        Logger.network.debug("⬅️ [RESPONSE] Status Code: \(httpResponse.statusCode)")
        
        if let responseBody = String(data: data, encoding: .utf8) {
            Logger.network.debug("📨 Response Body: \(responseBody)")
        }
    }
}
