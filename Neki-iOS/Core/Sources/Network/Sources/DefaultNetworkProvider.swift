//
//  DefaultNetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import os

public final actor DefaultNetworkProvider: NetworkProvider {
    private let session: URLSessionProtocol
    private let credentialBroker: any NetworkCredentialBroker
    private let decoder: JSONDecoder
    private let reportCredentialFailure: @Sendable (NetworkCredentialFailure, @escaping @Sendable () async -> Bool) async -> Void

    init(
        session: URLSessionProtocol = URLSession.shared,
        credentialBroker: any NetworkCredentialBroker,
        decoder: JSONDecoder = JSONDecoder(),
        reportCredentialFailure: @escaping @Sendable (NetworkCredentialFailure, @escaping @Sendable () async -> Bool) async -> Void
    ) {
        self.session = session
        self.credentialBroker = credentialBroker
        self.reportCredentialFailure = reportCredentialFailure
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        decoder.dateDecodingStrategy = .formatted(formatter)
        self.decoder = decoder
    }
    
    /// 네트워크 요청을 수행하고 별도의 응답 데이터 없이 성공 여부만 판단합니다.
    /// 임시 구현 - Presigned URL 요청 시에만 사용합니다
    public func requestVoid(endpoint: Endpoint) async throws -> Void {
        guard endpoint.credentialOperation == .none else {
            let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: endpoint)
            return
        }
        guard endpoint.authorizationType == .none else {
            let generation = await credentialBroker.credentialGeneration
            do { _ = try await performDataRequest(endpoint: endpoint, generation: generation) }
            catch let failure as NetworkCredentialFailure {
                guard await credentialBroker.isCurrent(generation: failure.credentialGeneration) else { throw CancellationError() }
                throw NetworkError.unauthorizedError
            }
            return
        }
        // Presigned URL 업로드의 기존 응답/오류 계약은 변경하지 않습니다.
        let request = try endpoint.asURLRequest()
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
        try await performRequest(endpoint: endpoint)
    }
    
    /// 네트워크 요청을 수행하고 제네릭 타입으로 응답 데이터를 디코딩합니다.
    public func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        try await performRequest(endpoint: endpoint)
    }
}


// MARK: - Core Logics

private extension DefaultNetworkProvider {
    func performRequest<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        try Task.checkCancellation()
        let generation = await credentialBroker.credentialGeneration
        do {
            let data = try await performDataRequest(endpoint: endpoint, generation: generation)
            try Task.checkCancellation()
            try await verifyAuthorizationGeneration(generation, for: endpoint)
            let response: BaseResponseDTO<T> = try decode(data: data)
            switch endpoint.credentialOperation {
            case .none: break
            case .replaceOnSuccess:
                guard let tokens = response.data as? any TokenContainer else { throw NetworkError.responseDecodingError }
                try await credentialBroker.store(tokens.toEntity(), matchingGeneration: generation)
            case .removeOnSuccess:
                guard try await credentialBroker.removeCredentials(matchingGeneration: generation) else { throw CancellationError() }
            }
            return response
        } catch let failure as NetworkCredentialFailure {
            guard await credentialBroker.isCurrent(generation: failure.credentialGeneration) else { throw CancellationError() }
            throw NetworkError.unauthorizedError
        } catch {
            try Task.checkCancellation()
            try await verifyAuthorizationGeneration(generation, for: endpoint)
            throw error
        }
    }

    func performDataRequest(endpoint: Endpoint, generation: UUID) async throws -> Data {
        try Task.checkCancellation()
        try await verifyAuthorizationGeneration(generation, for: endpoint)
        let request = try endpoint.asURLRequest()
        guard endpoint.authorizationType == .bearer else {
            return try await executeValidatedRequest(request, authorizationType: endpoint.authorizationType)
        }

        do {
            return try await credentialBroker.performAuthenticatedRequest(using: self, generation: generation) { tokens, revision in
                try Task.checkCancellation()
                guard await self.credentialBroker.isUsable(generation: generation, revision: revision) else { throw CancellationError() }
                var authorizedRequest = request
                authorizedRequest.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
                let data = try await self.executeValidatedRequest(authorizedRequest)
                try Task.checkCancellation()
                guard await self.credentialBroker.isUsable(generation: generation, revision: revision) else { throw CancellationError() }
                return data
            }
        } catch let failure as NetworkCredentialFailure {
            guard await credentialBroker.isCurrent(generation: failure.credentialGeneration) else { throw CancellationError() }
            // 수신자는 조립 지점에서 연결합니다. Network는 AuthClient나 세션 스트림을 알지 않습니다.
            await reportCredentialFailure(failure) { [credentialBroker] in
                await credentialBroker.isCurrent(generation: failure.credentialGeneration)
            }
            throw failure
        }
    }

    func executeValidatedRequest(_ request: URLRequest, authorizationType: AuthorizationType = .none) async throws -> Data {
        let (data, response) = try await executeSession(with: request)
        try Task.checkCancellation()
        switch validateResponse(response, authorizationType: authorizationType) {
        case .success: return data
        case .unauthorized: throw NetworkError.unauthorizedError
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


// MARK: - Auth Retry Logic

private extension DefaultNetworkProvider {
    func verifyAuthorizationGeneration(_ generation: UUID, for endpoint: Endpoint) async throws {
        guard endpoint.authorizationType != .none || endpoint.credentialOperation != .none else { return }
        guard await credentialBroker.isCurrent(generation: generation) else { throw CancellationError() }
    }
}


// MARK: - Validate & Decode

private extension DefaultNetworkProvider {
    enum ResponseStatus {
        case success
        case unauthorized
        case failure(NetworkError)
    }
    
    func validateResponse(_ response: URLResponse, authorizationType: AuthorizationType) -> ResponseStatus {
        guard let httpResponse = response as? HTTPURLResponse else { return .failure(.responseError) }
        
        switch httpResponse.statusCode {
        case 200..<300: return .success
        case 400: return .failure(.badRequestError)
        case 401: return .unauthorized
        // 재발급 API는 Refresh Token 만료를 403으로 반환합니다. 일반 API의 403과 구분합니다.
        case 403 where authorizationType == .reissue: return .unauthorized
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
