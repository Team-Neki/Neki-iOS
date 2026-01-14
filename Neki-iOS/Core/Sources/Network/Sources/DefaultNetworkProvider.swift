//
//  DefaultNetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import os

public final actor DefaultNetworkProvider: NetworkProvider {
    
    private var refreshTask: Task<Void, Error>?
    
    private let session: URLSessionProtocol
    private let tokenStorage: TokenStorage
    private var tokenRefresher: TokenRefresher?
    private let decoder: JSONDecoder
    
    public init(
        session: URLSessionProtocol = URLSession.shared,
        tokenStorage: TokenStorage,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.tokenStorage = tokenStorage
        self.decoder = decoder
    }
    
    public func setTokenRefresher(_ refresher: TokenRefresher) { tokenRefresher = refresher }
    
    /// 네트워크 요청을 수행하고 별도의 응답 데이터 없이 성공 여부만 판단합니다.
    ///
    /// voidResponse를 수행합니다.
    /// HTTP 200~299 상태 코드는 Void 값을 반환합니다.
    public func request(endpoint: Endpoint) async throws {
        let _ = try await processRequest(endpoint: endpoint, retryCount: 1)
    }
    
    /// 네트워크 요청을 수행하고 제네릭 타입으로 응답 데이터를 디코딩합니다.
    ///
    /// decodableResponse를 수행합니다.
    /// HTTP 200~299 상태 코드는 `JSONDecoder`를 통해 `T` 타입으로 디코딩하여 반환합니다.
    public func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        let data = try await processRequest(endpoint: endpoint, retryCount: 1)
        return try decode(data: data)
    }
}


// MARK: - Core Logics

private extension DefaultNetworkProvider {
    func processRequest(endpoint: Endpoint, retryCount: Int) async throws -> Data {
        let request = try await buildRequest(for: endpoint)
    
        requestLog(request)
        
        let (data, response) = try await session.data(for: request, delegate: nil)
        
        responseLog(data: data, response: response)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.responseError
        }
        
        if (200..<300).contains(httpResponse.statusCode) { return data }
        
        return try await handleFailure(statusCode: httpResponse.statusCode, data: data, endpoint: endpoint, retryCount: retryCount)
    }
    
    func handleFailure(statusCode: Int, data: Data, endpoint: Endpoint, retryCount: Int) async throws -> Data {
        guard statusCode == 401 else {
            try throwIfServerError(data: data)
            throw mapError(statusCode: statusCode)
        }
        
        return try await handleUnauthorized(data: data, endpoint: endpoint, retryCount: retryCount)
    }
}


// MARK: - Build Request

private extension DefaultNetworkProvider {
    func buildRequest(for endpoint: Endpoint) async throws -> URLRequest {
        var request = try endpoint.asURLRequest()
        
        switch endpoint.authorizationType {
        case .none: break
        case .bearer: try appendBearerToken(to: &request)
        case .reissue: try appendRefreshToken(to: &request)
        }
        
        return request
    }
    
    func appendBearerToken(to request: inout URLRequest) throws {
        do {
            let tokens = try tokenStorage.fetch()
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        } catch TokenStorageError.notFound {
            throw NetworkError.unauthorizedError
        } catch {
            Logger.network.error("Token Fetch Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func appendRefreshToken(to request: inout URLRequest) throws {
        do {
            let tokens = try tokenStorage.fetch()
            let body = ["refreshToken": tokens.refreshToken]
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } catch TokenStorageError.notFound {
            throw NetworkError.unauthorizedError
        } catch is EncodingError {
            Logger.network.error("❌ Encoding Error: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.network.error("❌ Token Fetch Error: \(error.localizedDescription)")
            throw error
        }
    }
}


// MARK: - Auth Retry Logic

private extension DefaultNetworkProvider {
    func handleUnauthorized(data: Data, endpoint: Endpoint, retryCount: Int) async throws -> Data {
        if endpoint.authorizationType == .reissue || retryCount <= .zero {
            try throwIfServerError(data: data)
            try? tokenStorage.delete()
            throw NetworkError.unauthorizedError
        }
        
        try await performTokenRefresh()
        return try await processRequest(endpoint: endpoint, retryCount: retryCount - 1)
    }
    
    func performTokenRefresh() async throws {
        if let existingTask = refreshTask { return try await existingTask.value }
        
        let task = Task {
            defer { refreshTask = nil }
            
            guard let refresher = tokenRefresher else { throw NetworkError.unauthorizedError }
            let newTokens = try await refresher.refresh(provider: self)
            try tokenStorage.store(newTokens)
        }
        
        refreshTask = task
        try await task.value
    }
}


// MARK: - Validate & Decode

private extension DefaultNetworkProvider {
    func throwIfServerError(data: Data) throws {
        guard let failureDTO = try? decoder.decode(BaseFailedResponseDTO.self, from: data) else { return }
        throw NetworkError.apiError(failureDTO)
    }
    
    func mapError(statusCode: Int) -> NetworkError {
        switch statusCode {
        case 400: return .badRequestError
        case 401: return .unauthorizedError
        case 404: return .notFound
        case 500..<600: return .internalServerError
        default: return .unknownError
        }
    }
    
    func decode<T: Decodable>(data: Data) throws -> T {
        do {
            return try self.decoder.decode(T.self, from: data)
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
            Logger.network.debug("🧾 Headers: \(headers.description)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            Logger.network.debug("📦 Body: \(bodyString)")
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
