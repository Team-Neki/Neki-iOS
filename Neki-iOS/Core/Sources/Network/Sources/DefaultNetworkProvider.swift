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
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }
    
    public func setTokenRefresher(_ refresher: TokenRefresher) { tokenRefresher = refresher }
    
    // TODO: - 프로바이더 부분 수정 필요
    
    /// 네트워크 요청을 수행하고 별도의 응답 데이터 없이 성공 여부만 판단합니다.
    /// 임시 구현
    public func requestVoid(endpoint: Endpoint) async throws -> Void {
            let request = try await buildRequest(for: endpoint)
            
             requestLog(request)
            
            do {
                let (_, response) = try await session.data(for: request, delegate: nil)
                 responseLog(data: Data(), response: response)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.responseError
                }
                
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw NetworkError.networkFail
                }
                
                return
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
        let request = try await buildRequest(for: endpoint)
        let (data, response) = try await executeSession(with: request)
        
        switch validateResponse(response) {
        case .success:
            let decodedResponse: BaseResponseDTO<T> = try decode(data: data)
            if let tokenData = decodedResponse.data as? TokenContainer {
                Logger.network.debug("Tokens detected in Network response, Saving to token storage.")
                try? tokenStorage.store(tokenData.toEntity())
            }
            
            return decodedResponse
            
        case .unauthorized:
            return try await retryWithTokenRefresh(endpoint: endpoint, retryCount: retryCount)
            
        case .failure(let error):
            throw error
        }
    }
    
    func executeSession(with request: URLRequest) async throws -> (Data, URLResponse) {
        requestLog(request)
        
        do {
            let (data, response) = try await session.data(for: request, delegate: nil)
            responseLog(data: data, response: response)
            return (data, response)
        } catch {
            throw NetworkError.unknownError(error)
        }
    }
}


// MARK: - Build Request

private extension DefaultNetworkProvider {
    func buildRequest(for endpoint: Endpoint) async throws -> URLRequest {
        var request = try endpoint.asURLRequest()
        
        switch endpoint.authorizationType {
        case .none: break
        case .bearer: request = try appendBearerToken(to: request)
        case .reissue: request = try appendRefreshToken(to: request)
        }
        
        return request
    }
    
    func appendBearerToken(to request: URLRequest) throws -> URLRequest {
        var newRequest = request
        
        // 이미지 업로드 테스트를 위한 임시 토큰
        var temporaryToken: String {
            guard let token = Bundle.main.infoDictionary?["TEMPORARY_ACCESS_TOKEN"] as? String else {
                return NetworkError.invalidURLError.localizedDescription
            }
            
            return token
        }
        
        do {
            newRequest.setValue("Bearer \(temporaryToken)", forHTTPHeaderField: "Authorization")
//            let tokens = try tokenStorage.fetch()
//            newRequest.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
            return newRequest
        } catch TokenStorageError.notFound {
            throw NetworkError.unauthorizedError
        } catch {
            Logger.network.error("❌ Token Fetch Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func appendRefreshToken(to request: URLRequest) throws -> URLRequest {
        var newRequest = request
        
        do {
            let tokens = try tokenStorage.fetch()
            let body = ["refreshToken": tokens.refreshToken]
            newRequest.httpBody = try JSONEncoder().encode(body)
            newRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return newRequest
        } catch TokenStorageError.notFound {
            throw NetworkError.unauthorizedError
        } catch let error as EncodingError {
            Logger.network.error("❌ Encoding Error: \(error.localizedDescription)")
            throw NetworkError.requestEncodingError
        } catch {
            Logger.network.error("❌ Token Fetch Error: \(error.localizedDescription)")
            throw error
        }
    }
}


// MARK: - Auth Retry Logic

private extension DefaultNetworkProvider {
    func retryWithTokenRefresh<T: Decodable>(endpoint: Endpoint, retryCount: Int) async throws -> BaseResponseDTO<T> {
        guard endpoint.authorizationType != .reissue, retryCount > .zero else {
            try? tokenStorage.delete()
            throw NetworkError.unauthorizedError
        }
        
        try await performTokenRefresh()
        return try await performRequest(endpoint: endpoint, retryCount: retryCount - 1)
    }
    
    func performTokenRefresh() async throws {
        if let existingTask = refreshTask { return try await existingTask.value }
        
        let task = Task {
            defer { refreshTask = nil }
            
            guard let refresher = tokenRefresher else { throw NetworkError.unauthorizedError }
            let newToken = try await refresher.refresh(provider: self)
            Logger.network.debug("Token refreshed, Saving to token storage.")
            try tokenStorage.store(newToken)
        }
        
        refreshTask = task
        
        do {
            try await task.value
        } catch {
            throw error
        }
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
